import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const popoverTriggerList = document.querySelectorAll('[data-bs-toggle="popover"]')
    this.popoverList = [...popoverTriggerList].map((popoverTriggerEl) => new bootstrap.Popover(popoverTriggerEl))
  }

  disconnect() {
    this.popoverList.forEach((popover) => {
      popover.dispose()
    })
    delete this.popoverList
  }
}
