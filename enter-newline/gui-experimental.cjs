/**
 * OpenCode Desktop GUI plugin.
 *
 * Swaps the composer's Enter behaviour to the layout most chat apps call
 * "newline mode":
 *
 *   Enter          -> insert a newline (was: send)
 *   Ctrl/Cmd+Enter -> send / queue (was: the alternate steer/queue delivery)
 *   Shift+Enter    -> insert a newline (unchanged)
 *
 * The desktop app hard-codes Enter-to-send in its composer, so this cannot be
 * done from opencode.json. A GUI plugin command is the supported way to claim a
 * key before the composer sees it: commands listen on `document` in the capture
 * phase, and a command scoped to the composer with `editable: true` can take
 * Enter first.
 *
 * Loaded as a CommonJS `./gui-experimental` bundle, so it runs without a build
 * step. `@opencode/plugin/gui` is provided by the app at runtime.
 */

const gui = require("@opencode/plugin/gui")

const Plugin = gui.Plugin
const Command = gui.Command

/** The composer <form>. Kept as a selector so this file needs no app imports. */
const COMPOSER = '[data-component="composer"]'
/** The contenteditable that holds the prompt. */
const EDITOR = '[data-component="composer-editor"]'

function composerFromFocus() {
  const active = document.activeElement

  return active instanceof Element ? active.closest(COMPOSER) : null
}

function editorFromFocus() {
  const active = document.activeElement

  return active instanceof Element ? active.closest(EDITOR) : null
}

/**
 * The suggestion/history/command popover is a sibling of the composer form, so
 * look for its rows from the form's wrapper. While it is open, Enter belongs to
 * the list (confirm/select), exactly as before.
 */
function popoverOpen(composer) {
  return !!composer?.parentElement?.querySelector("[data-suggestion-id]")
}

/** The key event currently being dispatched, for the IME guard. */
function composingNow() {
  const event = window.event

  if (event && (event.isComposing || event.keyCode === 229)) return true

  return false
}

/** Insert a line break at the caret without submitting. Mirrors Shift+Enter. */
function insertLineBreak(editor) {
  try {
    // Chromium fires one `input` event for this, so the draft stays in sync.
    if (document.execCommand("insertLineBreak")) return
  } catch {}

  const selection = window.getSelection()

  if (!selection || selection.rangeCount === 0) return

  const range = selection.getRangeAt(0)
  range.deleteContents()

  const br = document.createElement("br")
  range.insertNode(br)
  range.setStartAfter(br)
  range.collapse(true)
  selection.removeAllRanges()
  selection.addRange(range)

  // The command path was unavailable, so report the change to the editor.
  try {
    editor.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertLineBreak" }))
  } catch {
    editor.dispatchEvent(new Event("input", { bubbles: true }))
  }
}

module.exports = Plugin.define({
  i18n: {
    en: {
      "command.newline": "Enter: insert a newline",
      "command.send": "Ctrl+Enter: send the prompt",
    },
    zh: {
      "command.newline": "Enter：插入换行",
      "command.send": "Ctrl+Enter：发送消息",
    },
    zht: {
      "command.newline": "Enter：插入換行",
      "command.send": "Ctrl+Enter：傳送訊息",
    },
  },
  setup(ctx) {
    // The command API does not hand the keyboard event to `run`, so track IME
    // composition ourselves. Without this, Enter that confirms a CJK candidate
    // would insert a newline instead.
    let composing = false

    const onCompositionStart = () => {
      composing = true
    }
    const onCompositionEnd = () => {
      composing = false
    }

    document.addEventListener("compositionstart", onCompositionStart, true)
    document.addEventListener("compositionend", onCompositionEnd, true)

    ctx.add(Command, () => ({
      id: "newline",
      title: ctx.t("command.newline"),
      section: "prompt",
      bind: "enter",
      editable: true,
      hidden: true,
      scope: COMPOSER,
      run() {
        const composer = composerFromFocus()
        const editor = editorFromFocus()

        if (!composer || !editor) return false
        if (composing || composingNow()) return false
        if (popoverOpen(composer)) return false

        insertLineBreak(editor)

        return
      },
    }))

    ctx.add(Command, () => ({
      id: "send",
      title: ctx.t("command.send"),
      section: "prompt",
      bind: "mod+enter",
      editable: true,
      hidden: true,
      scope: COMPOSER,
      run() {
        const composer = composerFromFocus()

        if (!composer) return false
        if (composing || composingNow()) return false
        if (popoverOpen(composer)) return false
        // Holding the key must not submit the same prompt twice.
        if (window.event?.repeat) return

        // `submit` is what plain Enter used to do. requestSubmit triggers the
        // composer form's own submit handler, so queueing and queue editing keep
        // their normal semantics.
        try {
          composer.requestSubmit()

          return
        } catch {
          const button = composer.querySelector('[data-action="composer-submit"]')

          if (!(button instanceof HTMLButtonElement) || button.disabled) return false

          button.click()

          return
        }
      },
    }))

    return () => {
      document.removeEventListener("compositionstart", onCompositionStart, true)
      document.removeEventListener("compositionend", onCompositionEnd, true)
    }
  },
})
