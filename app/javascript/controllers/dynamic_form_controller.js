import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  change(event) {
    for (const link of this.linkTargets) {
      const oldHref = link.href

      const search = new URLSearchParams(link.search)
      search.set(event.target.name, event.target.value)
      link.search = search

      if (link.href !== oldHref) {
        link.click()
      }
    }
  }
}
