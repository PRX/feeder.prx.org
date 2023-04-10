import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link", "extra"]
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
      const params = new URLSearchParams(link.search)

      // combine element with (optional) extra form fields
      params.set(element.name, element.value)
      for (const f of this.extraTargets) {
        params.set(f.name, f.value)
      }

      link.search = params
      if (link.href !== oldHref) {
        link.click()
      }
    }
  }
}
