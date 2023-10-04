import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  change(event) {
    for (const link of this.linkTargets) {
      const oldHref = link.href

      const search = new URLSearchParams(link.search)
      if (event.currentTarget.value) {
        search.set(event.currentTarget.name, event.currentTarget.value)
      } else {
        search.delete(event.currentTarget.name)
      }
      link.search = search

      if (link.href !== oldHref) {
        link.click()
      }
    }
  }
}
