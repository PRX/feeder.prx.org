import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger"]

  triggerTargetConnected(el) {
    new bootstrap.Popover(el, { html: true })
  }

  triggerTargetDisconnected(el) {
    bootstrap.Popover.getInstance(el).dispose()
  }
}
