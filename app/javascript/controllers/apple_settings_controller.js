import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "deliverySelect",
    "ownShowOnly",
    "mappedOnly",
    "connectedOnly",
    "disconnectOnly",
    "mappedLink",
    "deliverySettings",
  ]

  static values = { private: Boolean, deliveryWas: String }

  connect() {
    this.sync()
  }

  // The delivery select holds the config's target: blank for none, "own" for
  // this feed's own show, or a public feed's binding id. Only public feed
  // options carry a feed URL.
  sync() {
    // The default feed has no delivery section, so no delivery to choose.
    const option = this.hasDeliverySelectTarget ? this.deliverySelectTarget.selectedOptions[0] : null
    const delivery = option ? option.value : ""
    const feedUrl = option?.dataset.feedUrl
    const disconnects = this.disconnects(option, delivery)

    this.ownShowOnlyTargets.forEach((el) => el.classList.toggle("d-none", delivery !== "own"))
    this.mappedOnlyTargets.forEach((el) => el.classList.toggle("d-none", !feedUrl))
    this.connectedOnlyTargets.forEach((el) => el.classList.toggle("d-none", disconnects))
    this.disconnectOnlyTargets.forEach((el) => el.classList.toggle("d-none", !disconnects))
    this.deliverySettingsTargets.forEach((el) => el.classList.toggle("d-none", delivery === ""))

    if (this.hasMappedLinkTarget) {
      this.mappedLinkTarget.href = feedUrl || "#"
    }
  }

  // Mirrors Apple::FeedSettings#disconnects?: saving any delivery but this
  // feed's own show removes its connection, except a public feed that stays
  // without delivery.
  disconnects(option, delivery) {
    if (!option || delivery === "own") return false

    return this.privateValue || delivery !== "" || delivery !== this.deliveryWasValue
  }
}
