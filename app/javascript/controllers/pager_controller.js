import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["page", "prev", "next"]
  static values = {
    currentPosition: { type: Number, default: 0 },
    range: { type: Number, default: 6 },
    step: { type: Number, default: 1 },
  }

  currentPositionValueChanged() {
    this.pageTargets.forEach((el, index) => {
      if (this.inRange(index)) {
        el.classList.remove("d-none")
      } else {
        el.classList.add("d-none")
      }
    })
  }

  inRange(index) {
    return index >= this.currentPositionValue && index < this.currentPositionValue + this.rangeValue
  }

  pageForward() {
    if (this.currentPositionValue < this.pageTargets.length - this.rangeValue) {
      this.currentPositionValue += this.stepValue
      this.prevTarget.disabled = false
    }
    if (this.currentPositionValue === this.pageTargets.length - this.rangeValue) {
      this.nextTarget.disabled = true
    }
  }

  pageBackward() {
    if (this.currentPositionValue > 0) {
      this.currentPositionValue -= this.stepValue
      this.nextTarget.disabled = false
    }
    if (this.currentPositionValue === 0) {
      this.prevTarget.disabled = true
    }
  }
}
