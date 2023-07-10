import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { copy: String, tooltip: String }

  connect() {
    this.element.dataset.action = "clipboard#copy"
    this.tip = new bootstrap.Tooltip(this.element, { title: this.tooltipValue })
    this.tip.disable()
  }

  disconnect() {
    this.tip.dispose()
  }

  copy(event) {
    event.preventDefault()
    navigator.clipboard.writeText(this.copyValue)

    // briefly show "copied" tooltip
    this.tip.enable()
    this.tip.show()
    setTimeout(() => {
      this.tip.hide()
      this.tip.disable()
    }, 1000)
  }
}
