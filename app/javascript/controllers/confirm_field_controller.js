import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "message"]

  connect() {
    this.modal = new bootstrap.Modal(this.modalTarget, { backdrop: "static", keyboard: false })
  }

  confirm(event) {
    if (event.target.classList.contains("is-changed")) {
      this.field = event.target
      this.messageTarget.innerHTML = this.confirmMessage()
      this.modal.show()
    }
  }

  confirmOkay() {
    this.modal.hide()
  }

  confirmCancel() {
    this.field.value = this.field.dataset.valueWas
    this.field.dispatchEvent(new Event("change"))
    this.modal.hide()
  }

  confirmMessage() {
    const oldValue = this.field.dataset.valueWas
    const newValue = this.field.value

    const updateMsg = this.field.dataset.confirmWith
    const createMsg = this.field.dataset.confirmCreate
    const deleteMsg = this.field.dataset.confirmDelete

    // optionally show a different message when creating/deleting
    if (oldValue && newValue) {
      return this.templateMessage(oldValue, newValue, updateMsg)
    } else if (newValue) {
      return this.templateMessage(oldValue, newValue, createMsg || updateMsg)
    } else {
      return this.templateMessage(oldValue, newValue, deleteMsg || updateMsg)
    }
  }

  templateMessage(oldValue, newValue, msg) {
    return msg.replaceAll("{old}", oldValue).replaceAll("{new}", newValue)
  }
}
