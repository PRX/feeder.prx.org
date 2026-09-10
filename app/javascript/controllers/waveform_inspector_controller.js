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
    this.playheadColor = "rgba(256, 193, 7, 1)"

    this.zoomTarget.addEventListener("wheel", this.handleWheel(this))

    this.peaksOptions = {
      ...(this.hasZoomTarget && {
        zoomview: {
          container: this.zoomTarget,
          fontSize: 12,
          playheadColor: this.playheadColor,

          wheelMode: "scroll",

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
          playheadColor: this.playheadColor,

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

      waveformColor: "rgba(0, 114, 163, 0.5)",
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
      const duration = peaksInstance.player.getDuration()

      // Initialize zoom ranges.
      // Zoom levels must be powers of 2 to insure markers and playhead are rendered consistently.
      // Zoom scale must be greater than the original waveform scale to avoid Peak.js from throwing an error.
      self.minScale = zoomView._originalWaveformData.scale
      self.maxScale = zoomView._getScale(duration)
      self.minZoomExp = Math.ceil(Math.log2(self.minScale))
      self.maxZoomExp = Math.ceil(Math.log2(self.maxScale))
      self.zoomExp = self.minZoomExp
      zoomView.setZoom({ scale: Math.pow(2, self.zoomExp) })

      zoomView.setMinSegmentDragWidth(1)
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

      // Store peaks instances for later use.
      self.peaks = peaksInstance
      self.zoomView = zoomView

      // Initialize markers.
      if (self.markersValue) {
        self.initMarkers()
        self.updateSeekInput()
        this.seekTo(this.playerStartTime)
      }
    })
  }

  handleKeydown(evt) {
    const interactiveElements = ["A", "BUTTON", "INPUT", "TEXTAREA", "SELECT", "TRIX-EDITOR"]
    const hasModifier = evt.altKey || evt.shiftKey || evt.ctrlKey || evt.metaKey

    if (interactiveElements.includes(evt.target.tagName) || hasModifier) return

    evt.preventDefault()

    const { paused } = this.audioElement

    switch (evt.code) {
      case "Space":
        this.togglePlaying()
        break
      case "KeyK":
        this.togglePlaying()
        break
      case "KeyJ":
        this.seekBy(-5)
        break
      case "KeyL":
        this.seekBy(30)
        break
      case "Comma":
        if (paused) {
          this.seekBy(-1 / 30)
        }
        break
      case "Period":
        if (paused) {
          this.seekBy(1 / 30)
        }
        break
      case "Home":
        this.seekTo(this.playerStartTime || 0)
        break
      case "End":
        this.seekToRelative(1)
        break
      case "Digit1":
        this.seekToRelative(0.1)
        break
      case "Digit2":
        this.seekToRelative(0.2)
        break
      case "Digit3":
        this.seekToRelative(0.3)
        break
      case "Digit4":
        this.seekToRelative(0.4)
        break
      case "Digit5":
        this.seekToRelative(0.5)
        break
      case "Digit6":
        this.seekToRelative(0.6)
        break
      case "Digit7":
        this.seekToRelative(0.7)
        break
      case "Digit8":
        this.seekToRelative(0.8)
        break
      case "Digit9":
        this.seekToRelative(0.9)
        break
      case "Digit0":
        this.seekTo(0)
        break
      default:
        break
    }
  }

  handleWheel(evt) {
    // Zoom in/out when scrolling up/down with alt key pressed.
    if (evt.altKey && evt.wheelDeltaX === 0) {
      evt.preventDefault()

      if (evt.wheelDeltaY > 0) {
        this.zoomOut()
      } else if (evt.wheelDeltaY < 0) {
        this.zoomIn()
      }
    }
  }

  handleZoomIn() {
    this.zoomIn()
  }

  handleZoomOut() {
    this.zoomOut()
  }

  updateSeekInput() {
    this.playerStartTime = this.markersValue.at(0).endTime
    this.seekInputTarget.placeholder = convertSecondsToDuration(this.playerStartTime)
  }

  clearMarkers() {
    this.peaks?.points.removeAll()
    this.peaks?.segments.removeAll()
  }

  initMarkers() {
    if (!this.peaks) return

    const segments = []
    const points = []

    this.markersValue.forEach(({ id, labelText, startTime, endTime }) => {
      const optionsDefault = {
        editable: true,
      }

      if (startTime == null) return

      if (endTime != null) {
        segments.push({
          ...optionsDefault,
          id,
          labelText,
          startTime,
          endTime,

          ...(id === "preRoll" && { startTime: 0 }),

          ...(id === "postRoll" && {
            endTime: Math.ceil(endTime),
          }),
        })
      } else {
        points.push({
          ...optionsDefault,
          id,
          labelText,
          time: startTime,
        })

        // Add a placeholder segment for this point.
        const placeholderSegment = {
          id: `placeholder.segments.${id}`,
          startTime,
          endTime: startTime,
        }
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
      this.updateSeekInput()
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

  seekBy(seconds) {
    const { currentTime } = this.audioElement
    this.seekTo(currentTime + seconds)
  }

  seekToRelative(ratio) {
    const { duration } = this.audioElement
    this.seekTo(duration * ratio)
  }

  seekSubmit(event) {
    event.preventDefault()

    const { target } = event
    const { value } = target

    this.seekTo(value)

    target.value = ""
  }

  seekToInputValue() {
    this.seekTo(this.seekInputTarget.value.trim() || this.playerStartTime)
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
    this.zoomExp = Math.max(this.zoomExp - 1, this.minZoomExp)

    const scale = Math.pow(2, this.zoomExp)

    this.zoomView.setZoom({ scale })
  }

  zoomOut() {
    this.zoomExp = Math.min(this.zoomExp + 1, this.maxZoomExp)

    const scale = Math.min(Math.pow(2, this.zoomExp), this.maxScale)

    this.zoomView.setZoom({ scale })
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
