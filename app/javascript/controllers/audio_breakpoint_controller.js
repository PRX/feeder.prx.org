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
    if (!this.hasStartTimeTarget) return

    if (this.hasInitialMarkerValue) {
      const isChanged = this.hasStartTimeValue && this.startTimeValue !== (this.initialMarkerValue.startTime || 0)

      this.startTimeTarget.parentNode.classList.toggle("js-is-changed", isChanged)
    } else {
      this.startTimeTarget.parentNode.classList.add("js-is-changed")
    }

    if (this.hasStartTimeValue) {
      this.startTimeTarget.placeholder = convertSecondsToDuration(this.startTimeValue)
    } else if (this.idValue === 'postRoll') {
      this.startTimeTarget.placeholder = convertSecondsToDuration(this.initialMarkerValue.endTime)
    }
  }

  endTimeValueChanged() {
    if (!this.hasEndTimeTarget) return

    if (this.hasInitialMarkerValue) {
      const isChanged = this.hasEndTimeValue && this.endTimeValue !== (this.initialMarkerValue.endTime || 0)

      this.endTimeTarget.parentNode.classList.toggle("js-is-changed", isChanged)

      if (this.hasStartTimeTarget) {
        const isStartTimeChanged =
          this.startTimeTarget.parentNode.classList.contains("js-is-changed") || (isChanged && !this.hasEndTimeValue)

        this.startTimeTarget.parentNode.classList.toggle("js-is-changed", isStartTimeChanged)
      }
    } else {
      this.endTimeTarget.parentNode.classList.add("js-is-changed")
    }

    if (this.hasEndTimeValue) {
      this.endTimeTarget.placeholder = convertSecondsToDuration(this.endTimeValue)
    }
  }

  updateStartTime(newTime) {
    this.dispatch("marker.update", {
      detail: {
        id: this.idValue,
        startTime: newTime || this.startTimeValue,
        ...(this.hasEndTimeValue && { endTime: this.endTimeValue }),
      },
    })
  }

  updateEndTime(newTime) {
    this.dispatch("marker.update", { detail: { id: this.idValue, startTime: this.startTimeValue, endTime: newTime } })
  }

  updateStartTimeToPlayhead() {
    this.dispatch("marker.update-start-time-to-playhead", {
      detail: {
        id: this.idValue,
        ...(this.hasEndTimeValue && { endTime: this.endTimeValue }),
      },
    })
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

  minEndTime() {
    this.updateEndTime(0)
  }

  maxStartTime() {
    this.updateStartTime(Infinity)
  }

  play() {
    this.dispatch("play", { detail: { id: this.idValue } })
  }

  seekTo() {
    this.dispatch("seekTo", { detail: { id: this.idValue } })
  }
}
