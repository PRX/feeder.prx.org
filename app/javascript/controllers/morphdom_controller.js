import { Controller } from "@hotwired/stimulus"
import morphdom from "morphdom"

export default class extends Controller {
  connect() {
    this.bindBeforeFrameRender = this.beforeFrameRender.bind(this)
    this.element.addEventListener("turbo:before-frame-render", this.bindBeforeFrameRender)
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-frame-render", this.bindBeforeFrameRender)
  }

  beforeFrameRender(event) {
    const childrenOnly = true
    const onBeforeElUpdated = this.shouldMorph

    event.detail.render = (currentElement, newElement) => {
      morphdom(currentElement, newElement, { childrenOnly, onBeforeElUpdated })
    }
  }

  // skip updating elements with data-morph="false"
  shouldMorph(el) {
    if (el.dataset.morph === "false" || el.dataset.morph === false) {
      return false
    } else {
      return true
    }
  }
}
