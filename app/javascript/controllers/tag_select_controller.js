import { Controller } from "@hotwired/stimulus"
import Tags from "bootstrap5-tags"

export default class extends Controller {
  connect() {
    if (!this.element.id) {
      this.element.setAttribute("id", Math.random().toString(16))
    }
    Tags.init("#" + this.element.id, {})

    // fixup styles
    this.tagContainer = this.element.nextSibling
    this.tagContainer.classList.add("form-tag-select")
    for (const cls of this.element.classList) {
      if (cls !== "form-select") {
        this.tagContainer.classList.add(cls)
      }
    }

    // fixup blank field controller
    this.bindChange = this.change.bind(this)
    this.element.addEventListener("change", this.bindChange)
  }

  disconnect() {
    this.element.removeEventListener("change", this.bindChange)
  }

  change(event) {
    if (this.element.value) {
      this.tagContainer.classList.remove("form-control-blank")
    } else {
      this.tagContainer.classList.add("form-control-blank")
    }
  }
}
