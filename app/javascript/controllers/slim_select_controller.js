import { Controller } from "@hotwired/stimulus"
import SlimSelect from "slim-select"

export default class extends Controller {
  static values = {
    exclusive: Array,
    maxValuesShown: { type: Number, default: 10 },
  }

  connect() {
    this.select = new SlimSelect({
      select: this.element,
      settings: {
        placeholderText: "",
        allowDeselect: this.hasEmpty(this.element),
        showSearch: this.showSearch(this.element),
        maxValuesShown: this.maxValuesShownValue,
      },
      events: {
        beforeChange: this.beforeChange.bind(this),
      },
    })
    // Ensure ARIA roles are applied to the actual list element (fix accessibility scanners)
    try {
      if (this.select && this.select.render && this.select.render.content) {
        const contentMain = this.select.render.content.main
        const contentList = this.select.render.content.list
        if (contentMain && contentMain.getAttribute && contentMain.getAttribute("role") === "listbox") {
          contentMain.removeAttribute("role")
        }
        if (contentList && contentList.setAttribute) {
          contentList.setAttribute("role", "listbox")
        }
      }
    } catch (err) {
      // silent fallback if structure differs
    }
    // Sanitize common misspelled ARIA attributes that some widgets may emit
    try {
      const sanitizeARIA = (root = document) => {
        const fixes = { 'aria-auto-complete': 'aria-autocomplete', 'aria-has-popup': 'aria-haspopup' }
        Object.keys(fixes).forEach((wrong) => {
          const els = root.querySelectorAll('[' + wrong + ']')
          els.forEach((el) => {
            const val = el.getAttribute(wrong)
            if (val !== null) {
              el.setAttribute(fixes[wrong], val)
              el.removeAttribute(wrong)
            }
          })
        })
      }
      sanitizeARIA(this.element)
      sanitizeARIA(document)
    } catch (e) {
      // ignore
    }
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
      if (element.children[i].dataset.mandatory) {
        return true
      }
    }
    return false
  }

  showSearch(element) {
    return element.children.length > 10
  }

  beforeChange(newVal, oldVal) {
    if (!newVal.length) {
      newVal = this.select.getData().filter((o) => o.mandatory)
    }

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
      this.select.setSelected(val)
    }, 1)
  }

  blankLater(val) {
    setTimeout(() => {
      if (val.length > 0) {
        this.select.selectEl.classList.remove("form-control-blank")
      } else {
        this.select.selectEl.classList.add("form-control-blank")
      }
    }, 10)
  }
}
