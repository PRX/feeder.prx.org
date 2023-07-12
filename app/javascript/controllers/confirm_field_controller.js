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
    if (this.field.type === "checkbox") {
      this.field.checked = this.field.dataset.valueWas === "true"
    } else {
      this.field.value = this.field.dataset.valueWas
    }
    this.field.dispatchEvent(new Event("change"))
    this.modal.hide()
  }

  confirmMessage() {
    const oldValue = this.labelForValue(this.field, this.field.dataset.valueWas)
    const newValue = this.labelForValue(this.field, this.field.value)

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

  // lookup labels for select options
  labelForValue(field, value) {
    if (field.options) {
      for (const opt of field.options) {
        if (opt.value === value) {
          return opt.textContent
        }
      }
    }

    return value
  }

  templateMessage(oldValue, newValue, msg) {
    return msg.replaceAll("{old}", oldValue).replaceAll("{new}", newValue)
  }
}
