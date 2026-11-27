/**
 * net-proxy — OpenCode server plugin.
 *
 * Applies a proxy switch to the running server process, so OpenCode Desktop
 * needs no launcher, no wrapper script and no local proxy daemon.
 *
 * Why this works without touching the transport:
 *   OpenCode's fetch calls (model requests, webfetch, websearch) run inside this
 *   same process, and Bun reads HTTP(S)_PROXY on every fetch. Setting or clearing
 *   those variables here therefore changes the next request, not just startup.
 *
 * Switch state (shared with the GUI and the CLI script):
 *   %USERPROFILE%\.config\opencode\net-proxy.json   (or $XDG_CONFIG_HOME/opencode)
 *
 *   { "mode": "auto" | "proxy" | "direct", "upstream": "http://127.0.0.1:7897" }
 *
 *   auto    do not manage; leave whatever the process inherited
 *   proxy   force HTTP_PROXY/HTTPS_PROXY/ALL_PROXY to `upstream`
 *   direct  remove them
 *
 * The upstream is probed once when `proxy` is applied. If it is unreachable the
 * server stays direct instead of losing every request, and the pill shows the
 * interruption. There is no periodic probe: switching back is manual.
 *
 * One instance per process: the plugin is loaded once per location, but the
 * environment, file watcher and RPC registration are shared and reference
 * counted. Every change is pushed to the GUI through the RPC `changed` event.
 */

import { Plugin } from "@opencode/plugin"
import { connect } from "node:net"
import { readFileSync, unwatchFile, watchFile, writeFileSync } from "node:fs"
import { homedir } from "node:os"
import { join } from "node:path"
import { NetProxy } from "./rpc"

const KEYS = [
  "HTTP_PROXY",
  "http_proxy",
  "HTTPS_PROXY",
  "https_proxy",
  "ALL_PROXY",
  "all_proxy",
] as const

const DEFAULT_UPSTREAM = "http://127.0.0.1:7897"
const PROBE_TIMEOUT_MS = 1500

type Mode = "auto" | "proxy" | "direct"
type Effective = "auto" | "proxy" | "direct"
type State = { mode: Mode; upstream: string }
type Snapshot = { mode: Mode; upstream: string; effective: Effective; available: boolean }

type Shared = {
  dispose: () => void
}

function statePath(): string {
  const configHome = process.env.XDG_CONFIG_HOME || join(homedir(), ".config")
  return join(configHome, "opencode", "net-proxy.json")
}

function isMode(value: unknown): value is Mode {
  return value === "auto" || value === "proxy" || value === "direct"
}

function normalizeUpstream(value: unknown, fallback: string): string {
  if (typeof value !== "string" || !value.trim()) return fallback
  const trimmed = value.trim()
  try {
    const url = new URL(trimmed)
    if (url.protocol === "http:") return trimmed
  } catch {}
  return fallback
}

function readState(fallback: State): State {
  try {
    const parsed = JSON.parse(readFileSync(statePath(), "utf8")) as Partial<State>
    return {
      mode: isMode(parsed.mode) ? parsed.mode : "auto",
      upstream: normalizeUpstream(parsed.upstream, fallback.upstream),
    }
  } catch {
    return fallback
  }
}

function saveState(state: State) {
  try {
    writeFileSync(statePath(), JSON.stringify({ mode: state.mode, upstream: state.upstream }, null, 2) + "\n")
  } catch (error) {
    console.log(`[net-proxy] cannot write ${statePath()}: ${(error as Error).message}`)
  }
}

function probe(upstream: string): Promise<boolean> {
  return new Promise((resolve) => {
    let url: URL
    try {
      url = new URL(upstream)
    } catch {
      resolve(false)
      return
    }

    const socket = connect({ host: url.hostname, port: Number(url.port || 80) })
    let settled = false
    const finish = (ok: boolean) => {
      if (settled) return
      settled = true
      socket.destroy()
      resolve(ok)
    }

    socket.setTimeout(PROBE_TIMEOUT_MS, () => finish(false))
    socket.once("connect", () => finish(true))
    socket.once("error", () => finish(false))
  })
}

async function createShared(ctx: { options: Record<string, unknown>; rpc: any }): Promise<Shared> {
  const file = statePath()
  const originals = new Map<string, string | undefined>()
  for (const key of KEYS) originals.set(key, process.env[key])

  const initial: State = {
    mode: isMode(ctx.options.mode) ? ctx.options.mode : "auto",
    upstream: normalizeUpstream(ctx.options.upstream, DEFAULT_UPSTREAM),
  }

  let state = readState(initial)
  let effective: Effective = state.mode
  let available = true
  let lastSummary = ""
  let publish: ((snapshot: Snapshot) => void) | undefined

  const restore = (key: string) => {
    const value = originals.get(key)
    if (value === undefined) delete process.env[key]
    else process.env[key] = value
  }

  const write = (target: Effective) => {
    for (const key of KEYS) {
      if (target === "proxy") process.env[key] = state.upstream
      else if (target === "direct") delete process.env[key]
      else restore(key)
    }
  }

  const snapshot = (): Snapshot => ({
    mode: state.mode,
    upstream: state.upstream,
    effective,
    available,
  })

  const apply = async (reason: string) => {
    if (state.mode === "proxy") {
      available = await probe(state.upstream)
      effective = available ? "proxy" : "direct"
    } else {
      available = true
      effective = state.mode
    }

    write(effective)

    const summary = `${state.mode}/${state.upstream}/${effective}/${available}`
    if (summary === lastSummary) return
    lastSummary = summary

    console.log(
      `[net-proxy] ${reason}: mode=${state.mode} effective=${effective} available=${available} ` +
        `upstream=${state.upstream} HTTPS_PROXY=${process.env.HTTPS_PROXY ?? ""}`,
    )
    publish?.(snapshot())
  }

  const registration = await ctx.rpc.register(NetProxy, {
    status: async () => snapshot(),

    set: async (input: unknown) => {
      const draft = (input ?? {}) as { mode?: unknown; upstream?: unknown }

      if (!isMode(draft.mode)) {
        throw new Error(`mode must be auto, proxy or direct, got: ${String(draft.mode)}`)
      }

      const upstream = draft.upstream === undefined ? state.upstream : draft.upstream
      if (typeof upstream !== "string" || !upstream.trim()) {
        throw new Error("upstream must be a non-empty http:// URL")
      }

      let parsed: URL
      try {
        parsed = new URL(upstream.trim())
      } catch {
        throw new Error(`upstream is not a URL: ${upstream}`)
      }
      if (parsed.protocol !== "http:") {
        throw new Error(`upstream must use http://, got: ${parsed.protocol}`)
      }

      state = { mode: draft.mode, upstream: upstream.trim() }
      saveState(state)
      await apply("rpc")
      return snapshot()
    },
  })

  publish = (value) => {
    void registration.events.emit("changed", value)
  }

  // Touch the environment only after the RPC is registered: if registration
  // fails, the process is left exactly as it was.
  await apply("loaded")

  watchFile(file, { interval: 1000 }, () => {
    const next = readState(state)
    if (next.mode === state.mode && next.upstream === state.upstream) return
    state = next
    void apply("reloaded")
  })

  return {
    dispose() {
      unwatchFile(file)
      for (const key of KEYS) restore(key)
      console.log("[net-proxy] unloaded, original environment restored")
    },
  }
}

let shared: Shared | undefined
let starting: Promise<Shared> | undefined
let references = 0

export default Plugin.define({
  id: "net-proxy",

  async setup(ctx) {
    const desktopOnly = ctx.options.desktopOnly !== false
    if (desktopOnly && process.env.OPENCODE_CLIENT !== "desktop") {
      console.log("[net-proxy] passive: OPENCODE_CLIENT is not desktop")
      return
    }

    if (!shared) {
      if (!starting) {
        starting = createShared(ctx as never)
          .then((value) => {
            shared = value
            return value
          })
          .finally(() => {
            starting = undefined
          })
      }
      await starting
    }

    const current = shared
    if (!current) return
    references += 1

    return () => {
      references -= 1
      if (references > 0) return
      if (shared === current) shared = undefined
      current.dispose()
    }
  },
})
