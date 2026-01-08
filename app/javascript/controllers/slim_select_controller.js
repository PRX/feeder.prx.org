import { Controller } from "@hotwired/stimulus"
import SlimSelect from "slim-select"

export default class extends Controller {
  static values = { groupSelect: Boolean, exclusive: Array }

  connect() {
    this.select = new SlimSelect({
      select: this.element,
      settings: {
        // TODO: broken
        // selectByGroup: this.groupSelectValue,
        placeholderText: "",
        allowDeselect: this.hasEmpty(this.element),
        showSearch: this.showSearch(this.element),
      },
      events: {
        afterChange: (val) => {
          if (val.length > 0) {
            this.select.selectEl.classList.remove("form-control-blank")
          } else {
            this.select.selectEl.classList.add("form-control-blank")
          }
          this.element.dispatchEvent(new Event("blur"))
        },
        beforeChange: (newOpts, oldOpts) => {
          if (this.exclusiveValue.length) {
            const newVals = newOpts.map((o) => o.value)
            const oldVals = oldOpts.map((o) => o.value)
            const added = newVals.find((v) => !oldVals.includes(v))
            const addedExclusive = this.exclusiveValue.includes(added) ? added : null
            const addedNonExclusive = !this.exclusiveValue.includes(added) ? added : null

            // deselect when adding an exclusive
            if (addedExclusive && oldVals.length) {
              this.select.setSelected([addedExclusive])
              return false
            }

            // deselect if exclusive is selected and we added non-exclusive
            if (oldVals.find((v) => this.exclusiveValue.includes(v)) && addedNonExclusive) {
              this.select.setSelected([addedNonExclusive])
              return false
            }
          }
          return true
        },
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
}
