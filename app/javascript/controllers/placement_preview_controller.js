import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["adBreaks", "button", "frame", "medium"]

  update(event) {
    const segments = parseInt(this.adBreaksTarget.value, 10) + 1
    const srcParts = this.frameTarget.src.split("/")
    srcParts[srcParts.length - 1] = segments

    // update lazy turboframe src for this number of original segments
    const src = srcParts.join("/")
    if (this.frameTarget.src !== src) {
      this.frameTarget.src = src
    }

    // hide preview button entirely for video
    if (this.mediumTarget.value == "video") {
      this.buttonTarget.classList.add("d-none")
    } else {
      this.buttonTarget.classList.remove("d-none")
    }
  }
}
