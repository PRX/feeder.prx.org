import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { changed: Boolean, confirm: String }
  static targets = ["discard"]

  connect() {
    this.isSubmitting = false
    this.isChanged = this.changedValue

    // bind listeners for page change
    this.bindChange = this.change.bind(this)
    this.bindSubmit = this.submit.bind(this)
    this.bindLeaving = this.leaving.bind(this)
    this.element.addEventListener("change", this.bindChange)
    this.element.addEventListener("submit", this.bindSubmit)
    window.addEventListener("beforeunload", this.bindLeaving)
    window.addEventListener("turbo:before-visit", this.bindLeaving)

    // set initial field values (if not already set)
    if (this.element.elements) {
      for (const el of this.element.elements || []) {
        if (!el.dataset.hasOwnProperty("valueWas")) {
          el.dataset.valueWas = this.getValue(el)
        }
      }
    }
  }

  disconnect() {
    this.element.removeEventListener("change", this.bindChange)
    this.element.removeEventListener("submit", this.bindSubmit)
    window.removeEventListener("beforeunload", this.bindLeaving)
    window.removeEventListener("turbo:before-visit", this.bindLeaving)
  }

  change(event) {
    if (this.isSubmitting) {
      return
    }

    // set is-changed indicator
    const valueWas = event.target.dataset.valueWas
    if (valueWas === undefined || valueWas !== this.getValue(event.target)) {
      event.target.classList.add("is-changed")
    } else {
      event.target.classList.remove("is-changed")
    }

    // scan for changes in form
    this.setChanged(!!this.element.querySelector(".is-changed"))
  }

  discard(event) {
    this.isChanged = false
  }

  submit(event) {
    this.isSubmitting = true
    this.setChanged(false)
  }

  // NOTE: for Turbo events, we can do whatever we want. But on regular
  // window:beforeunload, can only return a string to prompt.
  leaving(event) {
    if (this.confirmValue && this.isChanged && !this.isSubmitting) {
      if (event.type === "turbo:before-visit") {
        if (!window.confirm(this.confirmValue)) {
          event.preventDefault()
        } else {
          this.isChanged = false
        }
      } else {
        event.returnValue = this.confirmValue
        return this.confirmValue
      }
    }
  }

  getValue(element) {
    if (element.type === "checkbox") {
      return element.checked.toString()
    } else {
      return element.value
    }
  }

  setChanged(changed) {
    this.isChanged = changed

    if (this.hasDiscardTarget) {
      if (changed) {
        this.discardTarget.classList.remove("invisible")
      } else {
        this.discardTarget.classList.add("invisible")
      }
    }
  }
}
