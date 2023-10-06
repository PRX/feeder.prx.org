/**
 * Custom Peaks.js segment maker.
 */

import Konva from "konva"
import { Line } from "konva/lib/shapes/Line"
import { Rect } from "konva/lib/shapes/Rect"
import { Text } from "konva/lib/shapes/Text"

class PrxSegmentMarker {
  constructor(options) {
    this._options = options
    this._segment = options.segment
    this._peaks = options.layer._peaks
    this._lineWidth = 1
    this._handleWidth = 10
    this._handleHeight = 20
    this._tagCornerRadius = options.fontSize
    this._textPadding = options.fontSize / 2
    this._paddingX = 8
    this._paddingY = 8

    if (options.view === "zoomview") {
      const axisMarkerHeight = this._peaks.options.zoomview.axisBottomMarkerHeight || 10
      const axisMarkerFontSize = this._peaks.options.zoomview.fontSize || 11
      this._paddingBottom = axisMarkerHeight + axisMarkerFontSize + this._paddingY
    }

    if (
      (options.startMarker && this._segment.id === "preRoll") ||
      (!options.startMarker && this._segment.id === "postRoll")
    ) {
      this._disabled = true
    }

    if (!options.startMarker && this._segment.id === "preRoll") {
      this._isPreRollMarker = true
    }

    if (options.startMarker && this._segment.id === "postRoll") {
      this._isPostRollMarker = true
    }
  }

  init(group) {
    if (this._disabled) return

    // Label

    if (this._options.view === "zoomview" && (this._options.startMarker || this._isPreRollMarker)) {
      // Label - create with default y, the real value is set in fitToView().
      const label = new Konva.Label({
        x: 8,
        y: 0,
      })

      this._labelTag = new Konva.Tag({
        fill: this._options.color,
        lineJoin: "round",
        cornerRadius: this._tagCornerRadius,
      })
      label.add(this._labelTag)

      label.add(
        new Text({
          text: this._options.segment.labelText,
          textAlign: "right",
          fontFamily: this._options.fontFamily || "sans-serif",
          fontSize: this._options.fontSize || 10,
          fontStyle: this._options.fontStyle || "normal",
          padding: this._textPadding,
          fill: "#fff",
        })
      )

      this._label = label
    }

    // Handle - create with default y, the real value is set in fitToView().
    const handleX = -(this._handleWidth / 2) + 0.5 // Place in the middle of the marker
    const handle = new Konva.Group({
      x: handleX,
      y: 0,
    })

    handle.add(
      new Rect({
        width: this._handleWidth,
        height: this._handleHeight,
        fill: this._options.color,
      })
    )

    this._handle = handle

    // Line - create with default y and points, the real values
    // are set in fitToView().
    this._line = new Line({
      x: 0,
      y: 0,
      stroke: this._options.color,
      strokeWidth: 1,
    })

    // Time label

    // Time - create with default y, the real value is set in fitToView().
    const time = new Konva.Label({
      x: 0,
      y: 0,
    })
    const timeText = this._options.startMarker ? this._options.segment.startTime : this._options.segment.endTime

    this._timeTag = new Konva.Tag({
      fill: this._options.color,
      lineJoin: "round",
      cornerRadius: this._tagCornerRadius,
    })
    time.add(this._timeTag)

    this._timeText = new Text({
      text: this._options.layer.formatTime(timeText),
      textAlign: "left",
      fontFamily: this._options.fontFamily || "sans-serif",
      fontSize: this._options.fontSize || 10,
      fontStyle: this._options.fontStyle || "normal",
      padding: this._textPadding,
      fill: "#fff",
    })
    time.add(this._timeText)

    this._time = time

    this._time.hide()

    this._handle.add(this._time)

    group.add(this._line)

    if (this._handle) {
      group.add(this._handle)
    }

    if (this._label) {
      group.add(this._label)
    }

    this.fitToView()

    this.bindEventHandlers(group)
  }

  bindEventHandlers(group) {
    const self = this

    this._handle.on("mouseover touchstart", function () {
      self._time.show()
    })

    this._handle.on("mouseout touchend", function () {
      self._time.hide()
    })

    group.on("dragstart", function () {
      self._time.show()
    })

    group.on("dragend", function () {
      self._time.hide()
    })

    group.on("xChange", (evt) => {
      const layer = evt.currentTarget.getLayer()
      self._canvas = layer.canvas
      self._overlay =
        self._overlay || layer.children.find((child) => child.attrs.name === "overlay" && child.attrs.draggable)

      if (self._isPreRollMarker || self._isPostRollMarker) {
        self._overlay.draggable(false)
      }

      self.updateLabelPosition(evt.newVal)
      self.updateTimePosition(evt.newVal)
    })
  }

  updateLabelPosition(posX) {
    if (!this._label || !this._overlay) return

    if (this._isPreRollMarker || this._isPostRollMarker) {
      // Position Pre/Post roll marker label.
      this.positionPreOrPostRollLabel(posX)
    } else {
      // Position label sticky within bounds of segment overlay.
      this.positionLabelSticky(posX)
    }
  }

  positionPreOrPostRollLabel(posX) {
    const canvasWidth = this._canvas.getWidth()
    const labelWidth = this._label.getWidth()
    const offset = labelWidth / 2
    let newX = -offset
    let cornerRadius = this._tagCornerRadius

    if (posX <= offset) {
      newX = 0
      cornerRadius = [0, this._tagCornerRadius, this._tagCornerRadius, 0]
    }

    if (posX >= canvasWidth - offset) {
      newX = -labelWidth
      cornerRadius = [this._tagCornerRadius, 0, 0, this._tagCornerRadius]
    }

    this._label.x(newX)
    this._labelTag.cornerRadius(cornerRadius)
  }

  positionLabelSticky(posX) {
    const segmentWidth = this._overlay.getWidth()
    const labelWidth = this._label.getWidth()
    const rightBound = segmentWidth - this._paddingX - labelWidth
    let newX = this._paddingX

    if (posX < 0) {
      newX = Math.min(Math.abs(posX) + this._paddingX, rightBound)
    }

    this._label.x(newX)
  }

  updateTimePosition(posX) {
    if (!this._time || !this._canvas) return

    const canvasWidth = this._canvas.getWidth()
    const timeWidth = this._time.getWidth()

    if (
      (this._options.startMarker && posX < timeWidth) ||
      (!this._options.startMarker && posX < canvasWidth - timeWidth)
    ) {
      this._time.x(this._handleWidth - this._lineWidth / 2)
      this._timeTag.cornerRadius([0, this._tagCornerRadius, this._tagCornerRadius, 0])
    } else {
      this._time.x(-timeWidth + this._lineWidth / 2)
      this._timeTag.cornerRadius([this._tagCornerRadius, 0, 0, this._tagCornerRadius])
    }
  }

  fitToView() {
    if (this._disabled) return

    const height = this._options.layer.getHeight()

    this._line.points([0, 0, 0, height])

    if (this._label) {
      this._label.y(height - this._label.getHeight() - this._peaks.options.zoomview.fontSize - 16)
    }

    if (this._handle) {
      this._handle.y(height / 2 - 10.5)
    }
  }

  timeUpdated(time) {
    if (this._disabled) return

    if (this._time) {
      this._timeText.setText(this._options.layer.formatTime(time))
    }
  }
}

export default PrxSegmentMarker
