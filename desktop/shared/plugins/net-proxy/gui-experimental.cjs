/**
 * net-proxy — OpenCode Desktop GUI part.
 *
 * Adds a pill above the composer (next to the background-work and todo pills)
 * that switches the server-side proxy on, off, or back to "auto".
 *
 * No build step: this is a hand-written CommonJS bundle like the enter-newline
 * plugin. `@opencode/plugin/gui`, `@opencode/plugin/rpc` and `solid-js` are
 * provided by the app at runtime.
 *
 * The pill only talks to the server part over RPC; it never touches files or
 * environment variables itself (a window has no Node APIs).
 */

const gui = require("@opencode/plugin/gui")
const { Rpc } = require("@opencode/plugin/rpc")
const { createSignal } = require("solid-js")

// Plain JSON Schema on the GUI side: the window only needs the token id and the
// method names, and validation happens on the server against the Effect Schema
// contract. (2.4.2's RPC validators reject JSON Schema on the server, so the
// server part uses Effect Schema; see rpc.ts.)
const Status = {
  type: "object",
  properties: {
    mode: { type: "string" },
    upstream: { type: "string" },
    effective: { type: "string" },
    available: { type: "boolean" },
  },
  required: ["mode", "upstream", "effective", "available"],
  additionalProperties: false,
}

const NetProxy = Rpc.define({
  id: "net-proxy",
  methods: {
    status: { input: { type: "object", additionalProperties: false }, output: Status, errors: {} },
    set: {
      input: {
        type: "object",
        properties: {
          mode: { type: "string" },
          upstream: { type: "string" },
        },
        required: ["mode"],
        additionalProperties: false,
      },
      output: Status,
      errors: {},
    },
  },
  events: {
    changed: { schema: Status },
  },
})

const [view, setView] = createSignal({
  mode: "auto",
  upstream: "",
  effective: "auto",
  available: true,
  ready: false,
})

function label(v) {
  if (!v.ready) return "代理"
  if (v.mode === "auto") return "代理: 自动"
  if (v.mode === "direct") return "代理: 关"
  if (v.effective === "proxy") return "代理: 开"
  return "代理: 中断·直连"
}

function tone(v) {
  if (v.mode !== "proxy") return undefined
  return v.effective === "proxy" ? "success" : "danger"
}

module.exports = gui.Plugin.define({
  i18n: {
    en: {
      pill: "Proxy",
      on: "Use proxy",
      off: "Direct",
      auto: "Do not manage (auto)",
      toggle: "Proxy switch: on / off / auto",
    },
  },

  setup(ctx) {
    // The RPC client is read where it is used: it changes when the server restarts.
    const client = () => ctx.client.rpc(NetProxy)

    const update = (next) => setView({ ...next, ready: true })

    const refresh = async () => {
      try {
        update(await client().status({}))
      } catch {
        setView((current) => ({ ...current, ready: false }))
      }
    }

    const setMode = async (mode) => {
      try {
        update(await client().set({ mode }))
      } catch (error) {
        console.log(`[net-proxy] set ${mode} failed: ${error?.message ?? error}`)
        void refresh()
      }
    }

    // The server pushes every change, so there is no polling. A single retry
    // covers the window between GUI load and the server plugin registering.
    let unsubscribe = () => {}
    const subscribe = () => {
      try {
        unsubscribe = client().events.on("changed", (event) => update(event.data))
      } catch {
        // Server not ready yet; the retry below tries once more.
      }
    }

    void refresh()
    subscribe()
    const retry = setTimeout(subscribe, 3000)

    ctx.add(gui.ComposerPill, {
      id: "proxy",
      order: 1000,
      show: () => {
        const v = view()

        return {
          label: label(v),
          icon: "globe",
          tone: tone(v),
          title: v.upstream ? `代理开关 · ${v.upstream}` : "代理开关",
          rows: [
            {
              id: "on",
              label: "走代理",
              icon: "globe",
              detail: v.upstream,
              run: () => void setMode("proxy"),
            },
            {
              id: "off",
              label: "直连",
              run: () => void setMode("direct"),
            },
            {
              id: "auto",
              label: "不干预（auto）",
              run: () => void setMode("auto"),
            },
          ],
        }
      },
    })

    ctx.add(gui.Command, () => ({
      id: "toggle",
      title: "代理开关：开 / 关 / 自动",
      section: "prompt",
      bind: "mod+shift+p",
      slash: { name: "proxy", arguments: true },
      run: (input) => {
        const arg = String(input ?? "")
          .trim()
          .toLowerCase()

        if (arg === "on" || arg === "proxy") return void setMode("proxy")
        if (arg === "off" || arg === "direct") return void setMode("direct")
        if (arg === "auto") return void setMode("auto")

        const current = view()
        void setMode(current.mode === "proxy" ? "direct" : "proxy")
      },
    }))

    return () => {
      clearTimeout(retry)
      unsubscribe()
    }
  },
})
