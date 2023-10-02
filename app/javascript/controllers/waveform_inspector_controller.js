import { Controller } from "@hotwired/stimulus"
import Peaks from "peaks.js"
import _ from "lodash"
import convertToSeconds from "util/convertToSeconds"
import convertSecondsToDuration from "util/convertSecondsToDuration"
import PrxPointMarker from "custom/PrxPointMarker"
import PrxSegmentMarker from "custom/PrxSegmentMarker"

export default class extends Controller {
  static targets = ["overview", "zoom", "scrollbar", "seekInput"]

  static values = {
    audioUrl: String,
    waveformUrl: String,
    markers: Array,
  }

  static classes = ["playing"]

  updateLayout = _.debounce(() => {
    this.peaks?.views.getView("zoomview")?.fitToContainer()
    this.peaks?.views.getView("overview")?.fitToContainer()
  }, 500)

  connect() {
    this.audioElement = new Audio()
    this.audioElement.preload = "metadata"
    this.audioElement.src = this.audioUrlValue

    this.peaksOptions = {
      ...(this.hasZoomTarget && {
        zoomview: {
          container: this.zoomTarget,
          fontSize: 12,

          pointOptions: {
            labelTextColor: "#fff",
          },
        },
      }),
      ...(this.hasOverviewTarget && {
        overview: {
          container: this.overviewTarget,
          highlightOffset: 0,
          highlightBorderRadius: 0,
          highlightColor: "#8cd2f4",
          highlightOpacity: 0.3,
          segmentOptions: {
            overlayOpacity: 1,
            overlayOffset: 0,
            overlayFontSize: 0,
          },
        },
      }),
      ...(this.hasScrollbarTarget && {
        scrollbar: {
          container: this.scrollbarTarget,
          color: "#aaa",
          minWidth: 20,
        },
      }),
      mediaElement: this.audioElement,
      dataUri: {
        json: this.waveformUrlValue,
      },
      keyboard: true,
      emitCueEvents: true,
      showPlayheadTime: true,

      waveformColor: "rgba(0, 114, 163, 0.3)",
      playedWaveformColor: "rgba(0, 114, 163, 1)",

      createPointMarker: (options) => new PrxPointMarker(options),
      createSegmentMarker: (options) => (options.view === "zoomview" ? new PrxSegmentMarker(options) : null),
      createSegmentLabel: () => null,

      pointMarkerColor: "#ff9600",

      segmentOptions: {
        waveformColor: "#ff9600",
        startMarkerColor: "#ff9600",
        endMarkerColor: "#ff9600",
        overlay: true,
        overlayOffset: 0,
        overlayColor: "rgba(255, 193, 7, 0.3)",
        overlayOpacity: 1,
        overlayBorderWidth: 0,
        overlayCornerRadius: 0,
        overlayFontSize: 0,
        overlayLabelColor: "rgba(0, 0, 0, 0)",
      },
    }

    this.initPeaks()
  }

  initPeaks() {
    if (this.peaks) {
      this.peaks.destroy()
    }

    const self = this
    Peaks.init(this.peaksOptions, (err, peaksInstance) => {
      if (err) {
        console.error(err.message)
        return
      }

      const zoomView = peaksInstance.views.getView("zoomview")
      const overviewView = peaksInstance.views.getView("overview")

      zoomView.setAmplitudeScale(2)

      // Prevent segments from overlapping other segments.
      // We will also add some placeholder segments to prevent overlapping points.
      zoomView.setSegmentDragMode("no-overlap")

      // Allow segments to be move all at once, instead of just by the markers.
      zoomView.enableSegmentDragging(true)

      // Player Events
      peaksInstance.on("player.pause", () => {
        // Remove playing classes.
        self.element.classList.remove(...this.playingClasses)
      })

      peaksInstance.on("player.playing", () => {
        // Apply playing classes.
        self.element.classList.add(...this.playingClasses)
      })

      // Points Events
      peaksInstance.on("points.dragend", ({ point }) => {
        const { id, time } = point

        // Dispatch marker update event.
        self.dispatch("marker.update", { detail: { id, startTime: time } })
      })

      // Segment Events
      peaksInstance.on("segments.dragend", ({ segment }) => {
        const { id, startTime, endTime } = segment

        // Dispatch marker update event.
        self.dispatch("marker.update", { detail: { id, startTime, endTime } })
      })

      // Store peaks instance for later use.
      self.peaks = peaksInstance

      // Initialize markers.
      if (self.markersValue) {
        self.initMarkers()
      }
    })
  }

  clearMarkers() {
    this.peaks?.points.removeAll()
    this.peaks?.segments.removeAll()
  }

  initMarkers() {
    if (!this.peaks) return

    const segments = []
    const points = []

    console.log(this.peaks)

    this.markersValue.forEach(({ id, labelText, startTime, endTime }) => {
      const optionsDefault = {
        editable: true,
      }

      if (!startTime && startTime !== 0) return

      if (endTime) {
        segments.push({
          ...optionsDefault,
          id,
          labelText,
          startTime,
          endTime,
        })
      } else {
        points.push({
          ...optionsDefault,
          id,
          labelText,
          time: startTime
        })

        // Add a placeholder segment for this point.
        const placeholderSegment = {
          id: `placeholder.segments.${id}`,
          startTime: id === 'preRoll' ? 0 : startTime,
          endTime: id === 'postRoll' ? Math.ceil(this.peaks.player.getDuration()) : startTime
        }
        console.log(placeholderSegment)
        segments.push(placeholderSegment)
      }
    })

    this.peaks?.points.add(points)
    this.peaks?.segments.add(segments)
  }

  markersValueChanged() {
    if (this.markersValue?.length) {
      this.clearMarkers()
      this.initMarkers()
    }
  }

  togglePlaying() {
    if (this.audioElement.paused) {
      this.peaks.player.play()
    } else {
      this.peaks.player.pause()
    }
  }

  seekTo(time) {
    const seconds = convertToSeconds(time)

    if (seconds || seconds === 0) {
      this.peaks.player.seek(seconds)
    }
  }

  seekSubmit(event) {
    const { target } = event
    const { value } = target

    this.seekTo(value)

    target.value = ""
  }

  seekToInputValue() {
    this.seekTo(this.seekInputTarget.value)
    this.seekInputTarget.value = ""
  }

  seekToMarker({ detail }) {
    const { id } = detail || {}
    const marker = this.getMarker(id)

    if (marker) {
      const { startTime } = marker
      this.seekTo(startTime)
    }
  }

  playMarker({ detail }) {
    const { id } = detail || {}
    const marker = this.getMarker(id)

    if (marker) {
      const { startTime, endTime } = marker
      this.peaks.player.playSegment({ startTime, endTime })
    }
  }

  zoomIn() {
    this.peaks.zoom.zoomIn()
  }

  zoomOut() {
    this.peaks.zoom.zoomOut()
  }

  getMarker(id) {
    return this.markersValue.find((marker) => marker.id === id)
  }

  updateBreakpointMarkerStartTimeToPlayhead({ detail }) {
    const { id, endTime } = detail || {}

    // Dispatch marker update event.
    this.dispatch("marker.update", { detail: { id, startTime: this.peaks.player.getCurrentTime(), endTime } })
  }

  updateBreakpointMarkerEndTimeToPlayhead({ detail }) {
    const { id, startTime } = detail || {}

    // Dispatch marker update event.
    this.dispatch("marker.update", { detail: { id, startTime, endTime: this.peaks.player.getCurrentTime() } })
  }
}
