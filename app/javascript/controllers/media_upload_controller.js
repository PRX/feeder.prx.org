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
    const opts = { childrenOnly: true, onBeforeElUpdated: this.shouldMorph }

    // don't remove upload fields if segment count is invalid
    if (this.isInvalidSegmentCount(event.detail.newFrame)) {
      opts.onBeforeNodeDiscarded = this.shouldMorph
    }

    event.detail.render = (currentElement, newElement) => {
      morphdom(currentElement, newElement, opts)
    }
  }

  shouldMorph(el) {
    if ((el.dataset || {}).morph === "false") {
      return false
    } else {
      return true
    }
  }

  isInvalidSegmentCount(el) {
    const f1 = el.querySelector('[name="episode[segment_count]"]')
    const f2 = el.querySelector('[name="episode[ad_breaks]"]')
    return (f1 && f1.classList.contains("is-invalid")) || (f2 && f2.classList.contains("is-invalid"))
  }
}
