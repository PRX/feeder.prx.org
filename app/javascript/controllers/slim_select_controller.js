import { Controller } from "@hotwired/stimulus"
import SlimSelect from "slim-select"

export default class extends Controller {
  static values = { exclusive: Array }

  connect() {
    this.select = new SlimSelect({
      select: this.element,
      settings: {
        placeholderText: "",
        allowDeselect: this.hasEmpty(this.element),
        showSearch: this.showSearch(this.element),
      },
      events: {
        beforeChange: this.beforeChange.bind(this),
      },
    })
  }

  disconnect() {
    this.select.destroy()
  }

  hasEmpty(element) {
    for (let i = 0; i < element.children.length; i++) {
      if (element.children[i].innerText === "") {
        element.children[i].classList.add("d-none")
        return true
      }
    }
    return false
  }

  showSearch(element) {
    return element.children.length > 10
  }

  beforeChange(newVal, oldVal) {
    if (this.exclusiveValue.length) {
      const newVals = newVal.map((o) => o.value)
      const oldVals = oldVal.map((o) => o.value)
      const added = newVals.find((v) => !oldVals.includes(v))
      const addedExclusive = this.exclusiveValue.includes(added) ? added : null
      const addedNonExclusive = !this.exclusiveValue.includes(added) ? added : null

      // deselect when adding an exclusive
      if (addedExclusive !== null && oldVals.length) {
        this.selectLater([addedExclusive])
      }

      // deselect if exclusive is selected and we added non-exclusive
      if (oldVals.some((v) => this.exclusiveValue.includes(v)) && addedNonExclusive !== null) {
        this.selectLater([addedNonExclusive])
      }
    }

    // fix material-style floating labels as selection changes
    this.blankLater(newVal)

    return true
  }

  selectLater(val) {
    setTimeout(() => {
      this.select.setSelected([val])
    }, 1)
  }

  blankLater(val) {
    setTimeout(() => {
      if (val.length > 0) {
        this.select.selectEl.classList.remove("form-control-blank")
      } else {
        this.select.selectEl.classList.add("form-control-blank")
      }
    }, 1)
  }
}
