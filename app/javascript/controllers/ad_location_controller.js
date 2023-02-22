import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["label", "startTime", "endTime"]

  static values = {
    id: String,
    label: String,
    startTime: String,
    endTime: String
  }

  connect() {
    console.log("ad-location#connect", this.idValue, this.labelValue, this.startTimeValue, this.endTimeValue)
  }

  labelValueChanged(value) {
    console.log("ad-location#labelValueChanged >> labelValue", this.labelValue)
  }

  updateStartTime() {

  }
}
