import { Controller } from "@hotwired/stimulus"

const SELECTED = ["bg-primary", "text-light"]
const EXISTING = ["bg-warning"]
const DUPLICATE = ["bg-danger", "text-light"]

export default class extends Controller {
  static targets = ["container", "date", "title"]
  static values = { existing: Array, planning: Array }

  connect() {
    this.existingDates = this.existingValue.map((str) => {
      const localizedTime = new Date(str)

      // get date string in this timezone
      const year = localizedTime.getFullYear()
      const month = (localizedTime.getMonth() + 1).toString().padStart(2, "0")
      const date = localizedTime.getDate().toString().padStart(2, "0")
      return `${year}-${month}-${date}`
    })

    // trigger initial render
    this.planningValueChanged()
  }

  planningValueChanged() {
    if (this.existingDates) {
      for (const el of this.containerTargets) {
        this.setSelected(el)
      }
    }
  }

  toggleSelect(event) {
    this.setSelected(event.target, true)
  }

  setSelected(el, toggle = false) {
    const date = el.querySelector("[name='selected_dates[]']")
    const title = el.querySelector("[name='selected_titles[]']")
    const isExisting = this.existingDates.includes(date.value)

    // toggle or infer value from planned dates
    const isSelected = toggle ? !!date.disabled : this.planningValue.includes(date.value)

    // enable selected dates
    date.disabled = !isSelected
    title.disabled = !isSelected

    // set colors
    el.classList.remove(...SELECTED, ...EXISTING, ...DUPLICATE)
    if (isSelected && isExisting) {
      el.classList.add(...DUPLICATE)
    } else if (isSelected) {
      el.classList.add(...SELECTED)
    } else if (isExisting) {
      el.classList.add(...EXISTING)
    }
  }
}
