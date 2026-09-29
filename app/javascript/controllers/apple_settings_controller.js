import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["deliverySelect", "ownShowOnly", "mappedFeed", "mappedLink", "deliverySettings"]

  connect() {
    this.sync()
  }

  // The delivery select holds the config's target: blank for none, "own" for
  // this feed's own show, or a public feed's binding id.
  sync() {
    // The default feed has no delivery section, so no delivery to choose.
    const delivery = this.hasDeliverySelectTarget ? this.deliverySelectTarget.value : ""

    this.ownShowOnlyTargets.forEach((el) => el.classList.toggle("d-none", delivery !== "own"))
    this.deliverySettingsTargets.forEach((el) => el.classList.toggle("d-none", delivery === ""))

    if (this.hasDeliverySelectTarget) {
      this.syncMappedFeed()
    }
  }

  // The mapped feed link renders alongside the delivery select, so its targets
  // exist whenever the select does. Only public feed options carry a feed URL.
  syncMappedFeed() {
    const { feedUrl } = this.deliverySelectTarget.selectedOptions[0].dataset

    this.mappedFeedTarget.classList.toggle("d-none", !feedUrl)
    this.mappedLinkTarget.href = feedUrl || "#"
  }
}
