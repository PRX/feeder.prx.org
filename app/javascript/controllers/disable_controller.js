import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.dataset.action = `${this.element.dataset.action || ""} submit->disable#disableForm`
    this.uploadCount = 0
  }

  disableForm() {
    this.submitButtons().forEach((el) => {
      el.disabled = true
      el.value = el.dataset.disableWith || el.value
    })
  }

  uploading(disable = true) {
    if (disable) {
      this.uploadCount++
    } else {
      this.uploadCount--
    }
    this.submitButtons().forEach((el) => {
      if (this.uploadCount > 0) {
        el.disabled = true
        el.dataset.disableOriginal = el.dataset.disableOriginal || el.value
        el.value = el.dataset.uploadWith || el.value
      } else {
        el.disabled = false
        el.value = el.dataset.disableOriginal
      }
    })
  }

  submitButtons() {
    const submits1 = this.element.querySelectorAll('input[type="submit"]')
    const submits2 = this.element.id ? document.querySelectorAll(`input[type="submit"][form="${this.element.id}"]`) : []
    return Array.from(submits1).concat(Array.from(submits2))
  }
}
