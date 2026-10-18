import { Controller } from "@hotwired/stimulus"

// Renders a Cloudflare Turnstile widget. Invisible for most visitors
// (appearance: interaction-only); only shows a checkbox when Cloudflare
// requires interaction. With autoSubmit, the surrounding form is submitted
// as soon as a token is issued (used by the apply interstitial).
let scriptPromise

function loadTurnstile() {
  if (window.turnstile) return Promise.resolve()

  scriptPromise ||= new Promise((resolve) => {
    const script = document.createElement("script")
    script.src = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
    script.async = true
    script.onload = resolve
    script.onerror = () => {
      // Clear the memoized promise so a later connect() can retry, and resolve
      // so awaiting controllers proceed (render is guarded on window.turnstile).
      scriptPromise = undefined
      resolve()
    }
    document.head.appendChild(script)
  })

  return scriptPromise
}

export default class extends Controller {
  static values = { siteKey: String, action: String, autoSubmit: Boolean }

  connect() {
    this.disconnected = false
    // Turbo must never snapshot a rendered widget: restoring one leaves stale
    // iframe markup in the container, and rendering into a non-empty container
    // crashes the widget (TurnstileError 300030, no token ever minted).
    this.clearBeforeCache = () => this.reset()
    document.addEventListener("turbo:before-cache", this.clearBeforeCache)

    // A Turbo morph (page refresh, or a form re-rendered with 422 on a page
    // using turbo_refreshes_with :morph) strips the widget's markup but keeps
    // this controller connected, and the token it held is already spent.
    this.renderAfterMorph = (event) => {
      if (event.target === this.element) this.render()
    }
    this.element.addEventListener("turbo:morph-element", this.renderAfterMorph)

    this.render()
  }

  disconnect() {
    this.disconnected = true
    document.removeEventListener("turbo:before-cache", this.clearBeforeCache)
    this.element.removeEventListener("turbo:morph-element", this.renderAfterMorph)
    this.reset()
  }

  async render() {
    await loadTurnstile()
    if (this.disconnected || !window.turnstile) return

    this.reset() // defense against an already-cached snapshot or a morphed container
    this.widgetId = window.turnstile.render(this.element, {
      sitekey: this.siteKeyValue,
      action: this.actionValue,
      appearance: "interaction-only",
      "response-field-name": "cf_turnstile_response",
      callback: () => this.tokenReceived(),
      // A crashed widget can't mint a token; reset so the form stays usable
      // and the server-side retry flow takes over on submit.
      "error-callback": () => {
        this.reset()
        return true
      }
    })
  }

  tokenReceived() {
    if (this.disconnected) return
    if (this.autoSubmitValue) this.element.closest("form")?.requestSubmit()
  }

  reset() {
    if (this.widgetId) {
      window.turnstile.remove(this.widgetId)
      this.widgetId = null
    }
    this.element.replaceChildren()
  }
}
