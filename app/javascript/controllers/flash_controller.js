import { Controller } from "@hotwired/stimulus"

// Auto-dismisses a flash message after a few seconds; click also dismisses.
export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => this.dismiss(), 4500)
  }

  dismiss() {
    this.element.remove()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
