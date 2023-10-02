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
    this._lineWidth = 1
    this._handleWidth = 10
    this._handleHeight = 20
    this._tagCornerRadius = options.fontSize
    this._textPadding = options.fontSize / 2
    this._paddingX = 8
    this._paddingY = 8

    if (this._options.view === "zoomview") {
      const axisMarkerHeight = this._peaks.options.zoomview.axisBottomMarkerHeight || 10
      const axisMarkerFontSize = this._peaks.options.zoomview.fontSize || 11
      this._paddingBottom = axisMarkerHeight + axisMarkerFontSize + this._paddingY
    }
  }

  init(group) {

    // Label

    if (this._options.view === "zoomview") {
      // Label - create with default y, the real value is set in fitToView().
      const label = new Konva.Label({
        x: 0,
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
          text: this._options.point.labelText,
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

    if (this._options.draggable) {
      const handleX = -(this._handleWidth - this._lineWidth) / 2 // Place in the middle of the marker
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
    }

    // Line - create with default y and points, the real values
    // are set in fitToView().
    this._line = new Line({
      x: 0,
      y: 0,
      stroke: this._options.color,
      strokeWidth: this._lineWidth,
    })

    // Time label

    if (this._handle) {
      // Time - create with default y, the real value is set in fitToView().
      const time = new Konva.Label({
        x: 0,
        y: 0,
      })

      this._timeTag = new Konva.Tag({
        fill: this._options.color,
        lineJoin: "round",
        cornerRadius: [this._tagCornerRadius, 0, 0, this._tagCornerRadius],
      })
      time.add(this._timeTag)

      this._timeText = new Text({
        text: this._options.layer.formatTime(this._options.point.time),
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
      self._handle.on("mouseover touchstart", function () {
        self._time.show()
      })

      self._handle.on("mouseout touchend", function () {
        self._time.hide()
      })

      group.on("dragstart", function () {
        self._time.show()
      })

      group.on("dragend", function () {
        self._time.hide()
      })
    }

    group.on('xChange', (evt) => {
      const layer = evt.currentTarget.getLayer()

      self.updateLabelPosition(evt.newVal, layer)
      self.updateTimePosition(evt.newVal, layer)
    })
  }

  updateLabelPosition(posX, layer) {
    if(!this._label || !layer?.canvas) return

    const canvasWidth = layer.canvas.width
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

  updateTimePosition(posX, layer) {
    if(!this._time || !layer?.canvas) return

    const timeWidth = this._time.getWidth()

    if (posX < timeWidth) {
      this._time.x(this._handleWidth - this._lineWidth / 2)
      this._timeTag.cornerRadius([0, this._tagCornerRadius, this._tagCornerRadius, 0])
    } else {
      this._time.x(-timeWidth + this._lineWidth / 2)
      this._timeTag.cornerRadius([this._tagCornerRadius, 0, 0, this._tagCornerRadius])
    }
  }

  fitToView() {
    const height = this._options.layer.getHeight()

    this._line.points([0, 0, 0, height])

    if (this._label) {
      this._label.y(height - this._label.getHeight() - this._paddingBottom)
    }

    if (this._handle) {
      this._handle.y((height - this._handleHeight) / 2)
    }
  }

  timeUpdated(time) {
    if (this._time) {
      this._timeText.setText(this._options.layer.formatTime(time))
    }
  }
}

export default PrxPointMarker
