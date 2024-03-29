import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { changed: Boolean, confirm: String }
  static targets = ["discard", "changed"]

  connect() {
    this.isSubmitting = false
    this.setChanged(this.changedValue)

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

  changedTargetConnected(target) {
    this.change({ target })
  }

  change(event = null) {
    if (this.isSubmitting) {
      return
    }

    // set is-changed indicator
    if (event) {
      const valueWas = event.target.dataset.valueWas
      if (valueWas === undefined || valueWas !== this.getValue(event.target)) {
        event.target.classList.add("is-changed")
      } else {
        event.target.classList.remove("is-changed")
      }
    }

    this.setChanged(this.hasChangedFields())
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
    } else if (element.type === "select-multiple") {
      return JSON.stringify(Array.from(element.selectedOptions).map((o) => o.value))
    } else {
      return element.value
    }
  }

  setChanged(changed) {
    this.isChanged = changed

    if (this.hasDiscardTarget) {
      if (changed) {
        this.discardTarget.classList.remove("d-none")
      } else {
        this.discardTarget.classList.add("d-none")
      }
    }
  }

  hasChangedFields() {
    // scan for changes in form (ignoring slim select, which takes a bit to update)
    const changed = this.element.querySelectorAll(".is-changed")
    for (const el of changed) {
      if (el.classList.contains("ss-main")) {
        // ignore slimselect, which takes a bit to update
        continue
      } else if (el.classList.contains("if-visible") && !el.offsetParent) {
        // ignore SOME non-visible (offset parent will be null)
        continue
      } else {
        return true
      }
    }

    return false
  }
}
