import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]
  static values = { debounce: Number }

  change(event) {
    if (this.debounceValue) {
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => this.clickLinks(event.target), this.debounceValue)
    } else {
      this.clickLinks(event.target)
    }
  }

  clickLinks(element) {
    for (const link of this.linkTargets) {
      const oldHref = link.href
      link.search = new URLSearchParams({ [element.name]: element.value })
      if (link.href !== oldHref) {
        link.click()
      }
    }
  }
}
