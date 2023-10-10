import { Controller } from "@hotwired/stimulus"
import convertToSeconds from "util/convertToSeconds"
import convertSecondsToDuration from "util/convertSecondsToDuration"

export default class extends Controller {
  static targets = [
    "waveformInspector",
    "markersInput",
    "controls",
    "controlTemplate",
    "preRollControlTemplate",
    "postRollControlTemplate",
  ]

  static values = {
    duration: Number,
    labelPrefix: { type: String, default: "Breakpoint" },
    labelPreRoll: { type: String, default: "Pre-Roll" },
    labelPostRoll: { type: String, default: "Post-Roll" },
    adBreaks: { type: Number, default: 1 },
    adBreaksValid: { type: Boolean, default: false },
    segments: { type: Array, default: [] },
  }

  minTime = 0.000001

  connect() {
    this.initMarkers()
  }

  durationValueChanged() {
    const endTimeInput = this.postRollControlTemplateTarget.content.querySelector(
      '[data-audio-breakpoint-target="endTime"]'
    )

    endTimeInput?.setAttribute("placeholder", convertSecondsToDuration(this.durationValue))

    this.maxTime = this.durationValue - 0.01
  }

  /**
   * Handle external changes to incoming segments values.
   * Should only run when controller initializes, or we need to edit ad locations for a different episode.
   * DO NOT UPDATE THIS VALUE AS A RESULT OF EDITS IN THE AD LOCATIONS UI.
   */
  segmentsValueChanged(value) {
    if (!Array.isArray(value) || !value.length) return

    this.preRollPoint = value[0][0]
    this.postRollPoint = value[value.length - 1][1]
    this.adBreaks = value && [
      ...value.reduce((a, [, end1], index, all) => {
        if (index > all.length - 2) return a
        const [start2] = all[index + 1]
        return [...a, end1 !== start2 ? [end1, start2] : end1]
      }, []),
    ]

    if (!this.breakpointMarkers) return
    this.initMarkers()
  }

  adBreaksValueChanged() {
    if (!this.breakpointMarkers) return
    this.initMarkers()
  }

  /**
   * Initial render of ad markers.
   */
  initMarkers() {
    if (!this.hasSegmentsValue || !this.hasAdBreaksValue || !this.adBreaksValidValue) return

    const preRollMarker = this.breakpointMarkers?.shift()
    const postRollMarker = this.breakpointMarkers?.pop()
    const increasedBy = Math.max(0, this.adBreaksValue - this.breakpointMarkers?.length || 0)
    const allMarkers = [...(this.breakpointMarkers || []), ...(this.inactiveMarkers || [])]

    this.breakpointMarkers = [...Array(this.adBreaksValue).keys()]
      .map(
        (key) => (allMarkers[key] && [allMarkers[key].startTime, allMarkers[key].endTime]) || this.adBreaks?.[key] || []
      )
      .map((time, index) => ({
        id: allMarkers[index]?.id || Math.random().toString(16).split(".")[1],
        labelText: `${this.labelPrefixValue} ${index + 1}`,
        startTime: Array.isArray(time) ? time[0] : time,
        endTime: Array.isArray(time) ? time[1] : null,
      }))

    this.inactiveMarkers = allMarkers.slice(this.adBreaksValue)

    this.breakpointMarkers.unshift(
      preRollMarker || {
        id: "preRoll",
        labelText: this.labelPreRollValue,
        // Minimum times can not be zero or else segment doesn't render or function properly.
        startTime: this.minTime,
        endTime: this.preRollPoint || this.minTime,
      }
    )

    this.breakpointMarkers.push(
      postRollMarker || {
        id: "postRoll",
        labelText: this.labelPostRollValue,
        startTime: this.postRollPoint || this.maxTime,
        endTime: this.durationValue,
      }
    )

    this.initialMarkers = this.initialMarkers || this.breakpointMarkers

    if (increasedBy) {
      this.breakpointMarkers
        // Don't need to restore pre/post roll markers.
        .slice(1, -1)
        // Restore the number of markers the ad breaks were increased by from the end of active markers array.
        .slice(-increasedBy)
        .forEach(({ id, startTime, endTime }) => {
          this.restoreBreakpointMarker({ detail: { id, startTime, endTime } })
        })
    }

    this.updateBreakpointMarkers()
  }

  /**
   * Handle changes to a breakpoint marker.
   * @param CustomEvent Event containing changed marker data.
   */
  updateBreakpointMarker({ detail: { id, startTime, endTime } }) {
    const breakpointMarkerIndex = this.breakpointMarkers.findIndex((marker) => marker.id === id)
    const breakpointMarker = this.breakpointMarkers[breakpointMarkerIndex]

    if (!breakpointMarker) return

    const newStartTime = convertToSeconds(startTime)
    const newEndTime = convertToSeconds(endTime)
    const hasEndTime = newEndTime != null
    let newBreakpointMarker = {
      ...breakpointMarker,
      changed: new Date().getMilliseconds(),
      startTime: hasEndTime ? Math.max(this.minTime, Math.min(newStartTime, newEndTime, this.maxTime)) : newStartTime,
      endTime: hasEndTime ? Math.min(this.durationValue, Math.max(newStartTime, newEndTime, this.minTime)) : undefined,
    }
    const isSegment = !!newBreakpointMarker.endTime

    if (isSegment) {
      const previousBreakpointMarker = this.breakpointMarkers[breakpointMarkerIndex - 1]
      const nextBreakpointMarker = this.breakpointMarkers[breakpointMarkerIndex + 1]

      // Prevent marker from starting before previous marker's end time.
      if (previousBreakpointMarker) {
        newBreakpointMarker = {
          ...newBreakpointMarker,
          startTime: Math.max(
            newBreakpointMarker.startTime,
            previousBreakpointMarker.endTime || previousBreakpointMarker.startTime
          ),
        }
      }

      // Prevent marker from ending after next marker's start time.
      if (nextBreakpointMarker?.startTime) {
        newBreakpointMarker = {
          ...newBreakpointMarker,
          endTime: Math.min(newBreakpointMarker.endTime, nextBreakpointMarker.startTime),
        }
      }
    } else {
      const inValidStartTime =
        newBreakpointMarker.startTime <= this.minTime || newBreakpointMarker.startTime >= this.maxTime
      const intersectingSegment = this.breakpointMarkers.find(
        ({ id: iId, startTime: iStartTime, endTime: iEndTime }) =>
          id !== iId && newBreakpointMarker.startTime > iStartTime && newBreakpointMarker.startTime < iEndTime
      )

      // Prevent point marker from being dropped in a segment.
      if (intersectingSegment || inValidStartTime) {
        // If dropped on a segment, reset to original position.
        newBreakpointMarker = {
          ...newBreakpointMarker,
          startTime: breakpointMarker.startTime,
        }
      }
    }

    this.breakpointMarkers[breakpointMarkerIndex] = newBreakpointMarker

    this.updateBreakpointMarkers()
  }

  /**
   * Handle restoring an inactive breakpoint marker.
   * @param CustomEvent Event containing changed marker data.
   */
  restoreBreakpointMarker({ detail: { id, startTime, endTime } }) {
    const breakpointMarkerIndex = this.breakpointMarkers.findIndex((marker) => marker.id === id)
    const breakpointMarker = this.breakpointMarkers[breakpointMarkerIndex]

    if (!breakpointMarker) return

    const newStartTime = convertToSeconds(startTime)
    const newEndTime = convertToSeconds(endTime)
    const hasEndTime = newEndTime != null
    let newBreakpointMarker = {
      ...breakpointMarker,
      changed: new Date().getMilliseconds(),
      startTime: hasEndTime ? Math.min(newStartTime, newEndTime) : newStartTime,
      endTime: hasEndTime ? Math.max(newStartTime, newEndTime) : undefined,
    }
    const isSegment = !!newBreakpointMarker.endTime

    if (isSegment) {
      const intersectingSegment = this.breakpointMarkers.find(
        ({ id: iId, startTime: iStartTime, endTime: iEndTime }) =>
          (id !== iId &&
            ((newStartTime > iStartTime && newStartTime < iEndTime) ||
              (newEndTime > iStartTime && newEndTime < iEndTime))) ||
          (newStartTime < iStartTime && newEndTime > iEndTime)
      )

      if (
        intersectingSegment && // Fully covers restored breakpoint.
        ((intersectingSegment.startTime < newBreakpointMarker.startTime &&
          intersectingSegment.endTime > newBreakpointMarker.endTime) ||
          // Fully Covered by restored breakpoint.
          (intersectingSegment.startTime > newBreakpointMarker.startTime &&
            intersectingSegment.endTime < newBreakpointMarker.endTime))
      ) {
        newBreakpointMarker = {
          ...newBreakpointMarker,
          startTime: null,
          endTime: null,
        }
      } else if (intersectingSegment && intersectingSegment.startTime < newBreakpointMarker.startTime) {
        // Restored breakpoint overlaps end of active segment.
        newBreakpointMarker = {
          ...newBreakpointMarker,
          startTime: intersectingSegment.endTime,
        }
      } else if (intersectingSegment && intersectingSegment.endTime > newBreakpointMarker.endTime) {
        // Restored breakpoint overlaps start of active segment.
        newBreakpointMarker = {
          ...newBreakpointMarker,
          endTime: intersectingSegment.startTime,
        }
      }
    } else {
      const intersectingSegment = this.breakpointMarkers.find(
        ({ id: iId, startTime: iStartTime, endTime: iEndTime }) =>
          id !== iId && newBreakpointMarker.startTime > iStartTime && newBreakpointMarker.startTime < iEndTime
      )

      // Prevent point marker from being dropped in a segment.
      if (intersectingSegment) {
        // If restored within a segment, clear start tie so itt can be reset by user.
        newBreakpointMarker = {
          ...newBreakpointMarker,
          startTime: undefined,
        }
      }
    }

    this.breakpointMarkers[breakpointMarkerIndex] = newBreakpointMarker
  }

  /**
   * Update breakpoint markers after a change and rerender.
   */
  updateBreakpointMarkers() {
    this.sortBreakpointMarkers()

    this.renderMarkers()
  }

  /**
   * Render ad markers (form output, waveform update, location control fields).
   */
  renderMarkers() {
    // Convert ad markers to markers array.
    const newSegments = this.getSegmentsTimesArray()

    // Updated markers form input value.
    this.markersInputTarget.value = newSegments.length ? JSON.stringify(newSegments) : null
    this.markersInputTarget.dispatchEvent(new Event("change"))

    // Update waveform inspector.
    if (this.hasWaveformInspectorTarget) {
      this.waveformInspectorTarget.dataset.waveformInspectorMarkersValue = JSON.stringify(this.breakpointMarkers)
    }

    // Update controls
    if (this.hasControlsTarget && this.hasControlTemplateTarget) {
      this.renderAdMarkerControls()
    }
  }

  sortMarkers(markers) {
    return markers
      .sort((a, b) => (!a.startTime ? 1 : a.startTime - b.startTime))
      .map((marker, index) => ({
        ...marker,
        labelText: ["preRoll", "postRoll"].includes(marker.id) ? marker.labelText : `${this.labelPrefixValue} ${index}`,
      }))
  }

  /**
   * Sort ad markers by start time, in ascending order, and update label text.
   */
  sortBreakpointMarkers() {
    this.breakpointMarkers = this.sortMarkers(this.breakpointMarkers)
  }

  /**
   * Get ad markers as times only in array format. (e.g. [start, [start, end])
   * @returns Array of arrays containing start and end times for markers.
   */
  getSegmentsTimesArray() {
    return this.breakpointMarkers
      .filter(({ startTime }) => startTime !== undefined)
      .reduce((a, current, index, all) => {
        if (index >= all.length - 1) return a

        const startTime = current.endTime || current.startTime
        const next = all[index + 1]
        const segmentStart = startTime > this.minTime ? startTime : null
        const segmentEnd = (this.durationValue - next.startTime) * 100 > 10 ? next.startTime : null

        return [...a, [segmentStart, segmentEnd]]
      }, [])
  }

  renderAdMarkerControls() {
    const controls = []

    this.breakpointMarkers.forEach((marker, index) => {
      const templateTarget =
        (marker.id === "preRoll" && this.preRollControlTemplateTarget) ||
        (marker.id === "postRoll" && this.postRollControlTemplateTarget) ||
        this.controlTemplateTarget
      const template = templateTarget.content.cloneNode(true)
      const control = template.querySelector('[data-controller*="audio-breakpoint"]')
      const { id, labelText, startTime, endTime } = marker
      const initialMarker = this.initialMarkers.find(({ id: iId }) => iId === id)

      if (initialMarker) {
        control.dataset.audioBreakpointInitialMarkerValue = JSON.stringify(initialMarker)
      }

      control.dataset.audioBreakpointIdValue = id
      control.dataset.audioBreakpointLabelValue = labelText

      if (startTime != null && startTime > this.minTime && startTime < this.maxTime) {
        control.dataset.audioBreakpointStartTimeValue = startTime
      }

      if (endTime != null && endTime > this.minTime && endTime < this.maxTime) {
        control.dataset.audioBreakpointEndTimeValue = endTime
      }

      if (marker.id === "postRoll") {
        control.dataset.audioBreakpointEndTimeValue = endTime
        control
          .querySelector('[data-audio-breakpoint-target="startTime"]')
          .setAttribute("placeholder", convertSecondsToDuration(this.durationValue))
      }

      controls.push(control)
    })

    this.controlsTarget.replaceChildren(...controls)
  }
}
