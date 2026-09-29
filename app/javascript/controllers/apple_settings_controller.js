import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "ownShowCheckbox",
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
    const ownShow = this.hasOwnShowCheckboxTarget && this.ownShowCheckboxTarget.checked
    const mapped = this.hasMappingSelectTarget && this.mappingSelectTarget.value !== ""

    if (this.hasOwnShowCheckboxTarget) {
      this.ownShowOnlyTargets.forEach((el) => el.classList.toggle("d-none", !ownShow))
      this.mappingOnlyTargets.forEach((el) => el.classList.toggle("d-none", ownShow))
    }

    if (this.hasMappingSelectTarget) {
      this.syncMappedShow()
    }

    // Publishing settings only apply once delivery has a route: a public feed
    // mapping, or this feed's own show.
    this.deliverySettingsTargets.forEach((el) => el.classList.toggle("d-none", !(ownShow || mapped)))
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
