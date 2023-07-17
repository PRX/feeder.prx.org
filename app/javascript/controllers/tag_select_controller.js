import { Controller } from "@hotwired/stimulus"
import Tags from "bootstrap5-tags"

export default class extends Controller {
  connect() {
    if (!this.element.id) {
      this.element.setAttribute("id", Math.random().toString(16))
    }

    Tags.init("#" + this.element.id, {
      addOnBlur: true,
      hideNativeValidation: true,
      onBlur: () => this.element.dispatchEvent(new Event("blur")),
    })

    // fixup styles
    this.tagContainer = this.element.previousSibling
    this.tagContainer.classList.add("form-tag-select")
    for (const cls of this.element.classList) {
      this.tagContainer.classList.add(cls)
    }

    // fixup blank/changed status
    this.bindChange = this.change.bind(this)
    this.element.addEventListener("change", this.bindChange)
  }

  disconnect() {
    Tags.getInstance(this.element).dispose()
    this.element.removeEventListener("change", this.bindChange)
  }

  focus() {
    this.element.classList.remove("form-control-blank")
    this.tagContainer.classList.remove("form-control-blank")
  }

  change() {
    const valueWas = this.element.dataset.valueWas
    const values = Array.from(this.element.selectedOptions).map((o) => o.value)
    const valueIs = JSON.stringify(values)

    if (values.length) {
      this.tagContainer.classList.remove("form-control-blank")
    } else {
      this.tagContainer.classList.add("form-control-blank")
    }

    if (valueWas === valueIs) {
      this.tagContainer.classList.remove("is-changed")
    } else {
      this.tagContainer.classList.add("is-changed")
    }
  }
}
