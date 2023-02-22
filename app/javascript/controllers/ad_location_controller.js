import { Controller } from "@hotwired/stimulus"
import convertSecondsToDuration from "../util/convertSecondsToDuration"
import convertToSeconds from "../util/convertToSeconds"

export default class extends Controller {
  static targets = ["label", "startTime", "endTime"]

  static classes = ["completed"]

  static values = {
    id: String,
    label: String,
    startTime: String,
    endTime: String
  }

  connect() {
    console.log("ad-location#connect", this.idValue, this.labelValue, this.startTimeValue, this.endTimeValue)

    if (this.startTimeValue) {
      this.element.classList.add(...this.completedClasses)
    }
  }

  idValueChange() {
    this.playBtnTarget.dataset.adLocationIdParam = this.idValue
    this.seekBtnTarget.dataset.adLocationIdParam = this.idValue
  }

  labelValueChanged() {
    console.log("ad-location#labelValueChanged >> labelValue", this.labelValue)
    this.labelTarget.textContent = this.labelValue
  }

  startTimeValueChanged() {
    console.log("ad-location#startTimeValueChanged >> startTimeValue", this.startTimeValue)
    this.startTimeTarget.placeholder = convertSecondsToDuration(this.startTimeValue)
  }

  endTimeValueChanged() {
    console.log("ad-location#endTimeValueChanged >> endTimeValue", this.endTimeValue)
    this.endTimeTarget.placeholder = convertSecondsToDuration(this.endTimeValue)
  }

  updateStartTime(newTime) {
    this.dispatch('marker.update', { detail: { id: this.idValue, startTime: newTime || this.startTimeValue, endTime: this.endTimeValue }})
  }

  updateEndTime(newTime) {
    this.dispatch('marker.update', { detail: { id: this.idValue, startTime: this.startTimeValue, endTime: newTime }})
  }

  updateStartTimeToPlayhead() {
    const playheadTime = this.getPlayheadTime();

    if (playheadTime) {
      this.updateStartTime(playheadTime)
    }
  }

  updateEndTimeToPlayhead() {
    const playheadTime = this.getPlayheadTime();

    if (playheadTime) {
      this.updateEndTime(playheadTime)
    }
  }

  changeStartTime({ target }) {
    const { value } = target || {};
    this.updateStartTime(value);
  }

  changeEndTime({ target }) {
    const { value } = target || {};
    this.updateEndTime(value);
  }

  addEndTime() {
    this.updateEndTime(convertToSeconds(this.startTimeValue) + 1)
  }

  removeEndTime() {
    this.updateEndTime(null)
  }

  getPlayheadTime() {
    const playerContainer = this.element.closest("[data-playhead-time]")

    console.log("ad-location#getPlayheadTime", playerContainer?.dataset.playheadTime)

    return playerContainer ? playerContainer.dataset.playheadTime : 0;
  }

  play() {
    this.dispatch("play", { detail: { id: this.idValue }})
  }

  seekTo() {
    this.dispatch("seekTo", { detail: { id: this.idValue }})
  }
}
