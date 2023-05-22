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

  // skip some updates/deletes for segment_count changes
  beforeFrameRender(event) {
    const childrenOnly = true
    const onBeforeElUpdated = this.skipSegmentChanges
    const onBeforeNodeDiscarded = this.skipSegmentChanges

    event.detail.render = (currentElement, newElement) => {
      if (this.isParentTurboFrame(event.target)) {
        if (this.isInvalidSegmentCount(event.detail.newFrame)) {
          morphdom(currentElement, newElement, { childrenOnly, onBeforeElUpdated, onBeforeNodeDiscarded })
        } else {
          morphdom(currentElement, newElement, { childrenOnly, onBeforeElUpdated })
        }
      } else {
        morphdom(currentElement, newElement, { childrenOnly })
      }
    }
  }

  // skip changes to segment turbo-frames (they update themselves)
  skipSegmentChanges(el) {
    return (el.id || "").match(/episode-media-contents-[0-9]+/) ? false : true
  }

  isParentTurboFrame(el) {
    return el.id === "episode-form-audio"
  }

  isInvalidSegmentCount(el) {
    const f1 = el.querySelector('[name="episode[segment_count]"]')
    const f2 = el.querySelector('[name="episode[ad_breaks]"]')
    return (f1 && f1.classList.contains("is-invalid")) || (f2 && f2.classList.contains("is-invalid"))
  }
}
