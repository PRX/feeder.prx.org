import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  updateSlug(event) {
    this.setLinkPart(-2, event.target.value)
  }

  updateFileName(event) {
    this.setLinkPart(-1, event.target.value)
  }

  // https://host/1234/<slug>/<file_name>
  setLinkPart(offset, value) {
    const parts = this.linkTarget.value.split("/")
    const index = parts.length + offset
    parts[index] = value
    this.linkTarget.value = parts.join("/")
  }
}
