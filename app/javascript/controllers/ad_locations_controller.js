import { Controller } from "@hotwired/stimulus"
import convertToSeconds from "../util/convertToSeconds"

export default class extends Controller {
  static targets = ["waveformInspector", "markersInput", "controls", "controlTemplate"]

  static values = {
    labelPrefix: { type: String, default: "Ad Position" },
    segmentCount: { type: Number, default: 1 },
    markers: Array,
  }

  /**
   * Handle external changes to incoming marker values.
   * Should only run when controller initializes, or we need to edit ad locations for a different episode.
   * DO NOT UPDATE THIS VALUE AS A RESULT OF EDITS IN THE AD LOCATIONS UI.
   */
  markersValueChanged() {
    this.initMarkers()
  }

  /**
   * Initial render of ad markers.
   */
  initMarkers() {
    this.adMarkers = [...Array(this.segmentCountValue - 1).keys()]
      .map((key) => this.markersValue?.[key] || [])
      .map(([startTime, endTime], index) => ({
        id: Math.random().toString(16).split(".")[1],
        labelText: `${this.labelPrefixValue} ${index + 1}`,
        startTime,
        endTime,
      }))

    this.sortAdMarkers()

    this.renderMarkers()
  }

  /**
   * Handle changes to an ad marker.
   * @param CustomEvent Event containing changed marker data.
   */
  updateAdMarker({ detail: { id, startTime, endTime } }) {
    const adMarkerIndex = this.adMarkers.findIndex((marker) => marker.id === id)
    const adMarker = this.adMarkers[adMarkerIndex]
    const newStartTime = convertToSeconds(startTime)
    const newEndTime = endTime && convertToSeconds(endTime)

    this.adMarkers[adMarkerIndex] = {
      ...adMarker,
      startTime: newEndTime ? Math.min(newStartTime, newEndTime) : newStartTime,
      endTime: newEndTime ? Math.max(newStartTime, newEndTime) : newEndTime,
    }

    this.updateAdMarkers()
  }

  /**
   * Update ad markers after a change and rerender.
   */
  updateAdMarkers() {
    this.sortAdMarkers()

    this.renderMarkers()
  }

  /**
   * Render ad markers (form output, waveform update, location control fields).
   */
  renderMarkers() {
    // Convert ad markers to markers array.
    const markers = this.getMarkers()

    // Updated markers form input value.
    this.markersInputTarget.value = JSON.stringify(markers)

    // Update waveform inspector.
    if (this.hasWaveformInspectorTarget) {
      this.waveformInspectorTarget.dataset.waveformInspectorMarkersValue = JSON.stringify(this.adMarkers)
    }

    // Update controls
    if (this.hasControlsTarget && this.hasControlTemplateTarget) {
      this.renderAdMarkerControls()
    }
  }

  /**
   * Sort ad markers by start time, in ascending order, and update label text.
   */
  sortAdMarkers() {
    this.adMarkers = this.adMarkers
      .sort((a, b) => a.startTime - b.startTime)
      .map((marker, index) => ({
        ...marker,
        labelText: `${this.labelPrefixValue} ${index + 1}`,
      }))
  }

  /**
   * Get ad markers as times only in array format. (e.g. [[start], [start, end])
   * @returns Array of arrays containing start and end times for markers.
   */
  getMarkers() {
    return this.adMarkers.reduce(
      (a, { startTime, endTime }) => (startTime ? [...a, [startTime, ...(endTime ? [endTime] : [])]] : a),
      []
    )
  }

  renderAdMarkerControls() {
    const controls = []

    this.adMarkers.forEach((marker) => {
      const template = this.controlTemplateTarget.content.cloneNode(true)
      const control = template.querySelector('[data-controller*="ad-location"')
      const { id, labelText, startTime, endTime } = marker

      control.dataset.adLocationIdValue = id
      control.dataset.adLocationLabelValue = labelText

      if (startTime) {
        control.dataset.adLocationStartTimeValue = startTime
      }

      if (endTime) {
        control.dataset.adLocationEndTimeValue = endTime || null
      }

      controls.push(control)
    })

    this.controlsTarget.replaceChildren(...controls)
  }
}
