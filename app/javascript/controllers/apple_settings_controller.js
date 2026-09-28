import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "routeSelect",
    "ownShowOnly",
    "mappingOnly",
    "mappingSelect",
    "mappedShowGroup",
    "mappedShowField",
    "mappedLink",
    "deliverySettings",
  ]

  connect() {
    this.sync()
  }

  sync() {
    // The default feed has no delivery section, so no route to choose.
    const route = this.hasRouteSelectTarget ? this.routeSelectTarget.value : "none"

    this.ownShowOnlyTargets.forEach((el) => el.classList.toggle("d-none", route !== "own"))
    this.mappingOnlyTargets.forEach((el) => el.classList.toggle("d-none", route !== "mapped"))
    this.deliverySettingsTargets.forEach((el) => el.classList.toggle("d-none", route === "none"))

    if (this.hasMappingSelectTarget) {
      this.syncMappedShow()
    }
  }

  // The mapped show group renders alongside the mapping select, so its targets
  // exist whenever the select does. The blank option keeps one selected.
  syncMappedShow() {
    const { appleShowId, feedUrl } = this.mappingSelectTarget.selectedOptions[0].dataset

    this.mappedShowGroupTarget.classList.toggle("d-none", !appleShowId)
    this.mappedShowFieldTarget.value = appleShowId || ""
    this.mappedLinkTarget.href = feedUrl || "#"
  }
}
