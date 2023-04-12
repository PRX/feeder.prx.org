import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  change(event) {
    for (const link of this.linkTargets) {
      const oldHref = link.href
      link.search = new URLSearchParams({ [event.target.name]: event.target.value })
      if (link.href !== oldHref) {
        link.click()
      }
    }
  }
}
