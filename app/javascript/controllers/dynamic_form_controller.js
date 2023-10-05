import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  change(event) {
    const name = event.currentTarget.name
    const value = event.currentTarget.value
    const debounce = event.currentTarget.dataset.debounce

    if (debounce) {
      clearTimeout(this.timer)
      this.timer = setTimeout(() => this.updateAndClick(name, value), debounce)
    } else {
      this.updateAndClick(name, value)
    }
  }

  updateAndClick(name, value) {
    for (const link of this.linkTargets) {
      const oldHref = link.href

      const search = new URLSearchParams(link.search)
      if (value) {
        search.set(name, value)
      } else {
        search.delete(name)
      }
      link.search = search

      if (link.href !== oldHref) {
        link.click()
      }
    }
  }
}
