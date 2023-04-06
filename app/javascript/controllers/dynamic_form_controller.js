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

      // combine element with (optional) extra form fields
      const params = { [element.name]: element.value }
      for (const f of this.extraTargets) {
        params[f.name] = f.value
      }

      link.search = new URLSearchParams(params)
      if (link.href !== oldHref) {
        link.click()
      }
    }
  }
}
