import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    var tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'))
    this.tooltipList = tooltipTriggerList.map(function (tooltipTriggerEl) {
      return new bootstrap.Tooltip(tooltipTriggerEl)
    })
  }

  disconnect() {
    this.tooltipList.forEach((tooltip) => {
      tooltip.dispose()
    })
    delete this.tooltipList
  }
}
