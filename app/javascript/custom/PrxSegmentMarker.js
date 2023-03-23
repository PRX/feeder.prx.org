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
    this._peaks = options.layer._peaks
  }

  init(group) {
    const handleWidth = 10
    const handleHeight = 20
    const handleX = -(handleWidth / 2) + 0.5 // Place in the middle of the marker
    const tagCornerRadius = this._options.fontSize
    const textPadding = this._options.fontSize / 2
    const timeText = this._options.startMarker ? this._options.segment.startTime : this._options.segment.endTime
    const timeCornerRadius = this._options.startMarker
      ? [tagCornerRadius, 0, 0, tagCornerRadius]
      : [0, tagCornerRadius, tagCornerRadius, 0]

    // Label

    if (this._options.view === "zoomview" && this._options.startMarker) {
      // Label - create with default y, the real value is set in fitToView().
      const label = new Konva.Label({
        x: 8,
        y: 0,
      })

      label.add(
        new Konva.Tag({
          fill: this._options.color,
          lineJoin: "round",
          cornerRadius: tagCornerRadius,
        })
      )

      label.add(
        new Text({
          text: this._options.segment.labelText,
          textAlign: "right",
          fontFamily: this._options.fontFamily || "sans-serif",
          fontSize: this._options.fontSize || 10,
          fontStyle: this._options.fontStyle || "normal",
          padding: textPadding,
          fill: "#fff",
        })
      )

      this._label = label
    }

    // Handle - create with default y, the real value is set in fitToView().
    const handle = new Konva.Group({
      x: handleX,
      y: 0,
    })

    handle.add(
      new Rect({
        width: handleWidth,
        height: handleHeight,
        fill: this._options.color,
      })
    )

    this._handle = handle
    this._handleWidth = handleWidth

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

    time.add(
      new Konva.Tag({
        fill: this._options.color,
        lineJoin: "round",
        cornerRadius: timeCornerRadius,
      })
    )

    this._timeText = new Text({
      text: this._options.layer.formatTime(timeText),
      textAlign: "left",
      fontFamily: this._options.fontFamily || "sans-serif",
      fontSize: this._options.fontSize || 10,
      fontStyle: this._options.fontStyle || "normal",
      padding: textPadding,
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
    const timeX = this._options.startMarker ? -this._time.getWidth() + 0.5 : self._handleWidth - 0.5

    this._handle.on("mouseover touchstart", function () {
      // Position text to the left of the marker
      self._time.setX(timeX)
      self._time.show()
    })

    this._handle.on("mouseout touchend", function () {
      self._time.hide()
    })

    group.on("dragstart", function () {
      self._time.setX(timeX)
      self._time.show()
    })

    group.on("dragend", function () {
      self._time.hide()
    })
  }

  fitToView() {
    const height = this._options.layer.getHeight()

    this._line.points([0.5, 0, 0.5, height])

    if (this._label) {
      this._label.y(height - this._label.getHeight() - this._peaks.options.zoomview.fontSize - 16)
    }

    if (this._handle) {
      this._handle.y(height / 2 - 10.5)
    }

    // if (this._time) {
    //   this._time.y(height / 2 - this._time.getHeight() / 2 - 0.5)
    // }
  }

  timeUpdated(time) {
    if (this._time) {
      this._timeText.setText(this._options.layer.formatTime(time))
    }
  }
}

export default PrxSegmentMarker
