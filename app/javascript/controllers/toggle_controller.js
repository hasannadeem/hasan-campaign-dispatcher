import { Controller } from "@hotwired/stimulus"

// Switches the recipient-entry form between its "paste" and "upload" panels.
export default class extends Controller {
  static targets = ["tab", "panel"]

  select(event) {
    const mode = event.currentTarget.dataset.mode

    this.panelTargets.forEach((p) => { p.hidden = p.dataset.mode !== mode })
    this.tabTargets.forEach((t) => {
      const on = t.dataset.mode === mode
      t.classList.toggle("bg-white", on)
      t.classList.toggle("shadow-sm", on)
      t.classList.toggle("text-zinc-900", on)
      t.classList.toggle("text-zinc-500", !on)
    })
  }
}
