import { Controller } from "@hotwired/stimulus"
import convertSecondsToDuration from "util/convertSecondsToDuration"
import convertToSeconds from "util/convertToSeconds"

export default class extends Controller {
  static targets = ["label", "startTime", "endTime"]

  static classes = ["completed"]

  static values = {
    initialMarker: Object,
    id: String,
    label: String,
    startTime: Number,
    endTime: Number,
  }

  connect() {
    if (this.startTimeValue) {
      this.element.classList.add(...this.completedClasses)
    }
  }

  idValueChange() {
    this.playBtnTarget.dataset.audioBreakpointIdParam = this.idValue
    this.seekBtnTarget.dataset.audioBreakpointIdParam = this.idValue
  }

  labelValueChanged() {
    this.labelTarget.textContent = this.labelValue
  }

  startTimeValueChanged() {
    if (this.hasInitialMarkerValue) {
      const isChanged = this.startTimeValue !== (this.initialMarkerValue.startTime || 0)

      this.startTimeTarget.parentNode.classList.toggle("is-changed", isChanged)
    } else {
      this.startTimeTarget.parentNode.classList.add("is-changed")
    }

    this.startTimeTarget.placeholder = convertSecondsToDuration(this.startTimeValue)
  }

  endTimeValueChanged() {
    if (this.hasInitialMarkerValue) {
      const isChanged = this.endTimeValue !== (this.initialMarkerValue.endTime || 0)
      const isStartTimeChanged =
        this.startTimeTarget.parentNode.classList.contains("is-changed") || (isChanged && !this.hasEndTimeValue)

      this.endTimeTarget.parentNode.classList.toggle("is-changed", isChanged)
      this.startTimeTarget.parentNode.classList.toggle("is-changed", isStartTimeChanged)
    } else {
      this.endTimeTarget.parentNode.classList.add("is-changed")
    }

    this.endTimeTarget.placeholder = convertSecondsToDuration(this.endTimeValue)
  }

  updateStartTime(newTime) {
    this.dispatch("marker.update", {
      detail: { id: this.idValue, startTime: newTime || this.startTimeValue, endTime: this.endTimeValue },
    })
  }

  updateEndTime(newTime) {
    this.dispatch("marker.update", { detail: { id: this.idValue, startTime: this.startTimeValue, endTime: newTime } })
  }

  updateStartTimeToPlayhead() {
    this.dispatch("marker.update-start-time-to-playhead", { detail: { id: this.idValue, endTime: this.endTimeValue } })
  }

  updateEndTimeToPlayhead() {
    this.dispatch("marker.update-end-time-to-playhead", {
      detail: { id: this.idValue, startTime: this.startTimeValue },
    })
  }

  changeStartTime() {
    const { value } = this.startTimeTarget
    this.updateStartTime(value)
  }

  changeEndTime() {
    const { value } = this.endTimeTarget
    this.updateEndTime(value)
  }

  addEndTime() {
    this.updateEndTime(convertToSeconds(this.startTimeValue) + 1)
  }

  removeEndTime() {
    this.updateEndTime(null)
  }

  play() {
    this.dispatch("play", { detail: { id: this.idValue } })
  }

  seekTo() {
    this.dispatch("seekTo", { detail: { id: this.idValue } })
  }
}
