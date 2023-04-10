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

  // morph turbo-frames, instead of replacing
  beforeFrameRender(event) {
    console.log("beforeFrameRender")
    event.detail.render = (currentElement, newElement) => {
      morphdom(currentElement, newElement, { childrenOnly: true })
    }
  }
}
