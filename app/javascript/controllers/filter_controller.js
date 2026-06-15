import { Controller } from "@hotwired/stimulus"

// Auto-submits a GET filter form into its Turbo Frame: debounced while typing,
// immediate when a status chip changes.
export default class extends Controller {
  debounced() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), 250)
  }

  submit() {
    this.element.requestSubmit()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
