import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  updateSlug(event) {
    this.addBlurAction(event.target)
    this.setLinkPart(-2, event.target.value)
    this.showLink(0)
  }

  updateFileName(event) {
    this.addBlurAction(event.target)
    this.setLinkPart(-1, event.target.value)
    this.showLink(1)
  }

  // https://host/1234/<slug>/<file_name>
  setLinkPart(offset, value) {
    const parts = this.linkTarget.href.split("/")
    const index = parts.length + offset
    parts[index] = value
    const newHref = parts.join("/")
    for (const link of this.linkTargets) {
      link.href = newHref
      link.textContent = newHref
    }
  }

  showLink(offset) {
    const link = this.linkTargets[offset] || this.linkTarget
    link.classList.remove("d-none")
  }

  hideLink() {
    for (const link of this.linkTargets) {
      link.classList.add("d-none")
    }
  }

  addBlurAction(el) {
    const action = el.dataset.action || ""
    el.dataset.action = `${action} blur->feed-link#hideLink`
  }
}
