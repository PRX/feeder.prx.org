import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "deliverySelect",
    "ownShowOnly",
    "mappedShowGroup",
    "mappedShowField",
    "mappedLink",
    "deliverySettings",
  ]

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
      this.syncMappedShow()
    }
  }

  // The mapped show group renders alongside the delivery select, so its targets
  // exist whenever the select does. Only public feed options carry a show.
  syncMappedShow() {
    const { appleShowId, feedUrl } = this.deliverySelectTarget.selectedOptions[0].dataset

    this.mappedShowGroupTarget.classList.toggle("d-none", !appleShowId)
    this.mappedShowFieldTarget.value = appleShowId || ""
    this.mappedLinkTarget.href = feedUrl || "#"
  }
}
