/**
 * Custom Peaks.js point maker.
 */

import Konva from "konva"
import { Line } from "konva/lib/shapes/Line"
import { Rect } from "konva/lib/shapes/Rect"
import { Text } from "konva/lib/shapes/Text"

class PrxPointMarker {
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

    // Label

    if (this._options.view === "zoomview") {
      // Label - create with default y, the real value is set in fitToView().
      const label = new Konva.Label({
        x: 0,
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
          text: this._options.point.labelText,
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

    if (this._options.draggable) {
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
    }

    // Line - create with default y and points, the real values
    // are set in fitToView().
    this._line = new Line({
      x: 0,
      y: 0,
      stroke: this._options.color,
      strokeWidth: 1,
    })

    // Time label

    if (this._handle) {
      // Time - create with default y, the real value is set in fitToView().
      const time = new Konva.Label({
        x: 0,
        y: 0,
      })

      time.add(
        new Konva.Tag({
          fill: this._options.color,
          lineJoin: "round",
          cornerRadius: [tagCornerRadius, 0, 0, tagCornerRadius],
        })
      )

      this._timeText = new Text({
        text: this._options.layer.formatTime(this._options.point.time),
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
    }

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

    if (self._handle) {
      const timeX = -this._time.getWidth() + 0.5

      self._handle.on("mouseover touchstart", function () {
        // Position text to the left of the marker
        self._time.setX(timeX)
        self._time.show()
      })

      self._handle.on("mouseout touchend", function () {
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
  }

  fitToView() {
    const height = this._options.layer.getHeight()

    this._line.points([0.5, 0, 0.5, height])

    if (this._label) {
      this._label.x(-this._label.getWidth() / 2 - 0.5)
      this._label.y(height - this._label.getHeight() - this._peaks.options.zoomview.fontSize - 16)
    }

    if (this._handle) {
      this._handle.y(height / 2 - 10.5)
    }
  }

  timeUpdated(time) {
    if (this._time) {
      this._timeText.setText(this._options.layer.formatTime(time))
    }
  }
}

export default PrxPointMarker
