import { Controller } from "@hotwired/stimulus"

// mirror input changes to other display-only elements
const mirror = (toElements, text, value, valueWas = null) => {
  toElements.forEach((el) => {
    el.innerHTML = value ? text : "&mdash;"
    if (valueWas && valueWas !== value) {
      el.classList.add("is-changed")
    } else {
      el.classList.remove("is-changed")
    }
  })
}

export default class extends Controller {
  static targets = ["name", "nameField", "role", "organization", "href", "edit", "destroy"]

  change(event) {
    const el = event.currentTarget
    const value = el.value
    const valueWas = el.dataset.valueWas

    if (el.name.endsWith("[name]")) {
      mirror(this.nameTargets, value, value, valueWas)
    } else if (el.name.endsWith("[role]")) {
      const text = el.options[el.selectedIndex].text
      mirror(this.roleTargets, text, value, valueWas)
    } else if (el.name.endsWith("[organization]")) {
      mirror(this.organizationTargets, value, value, valueWas)
    } else if (el.name.endsWith("[href]")) {
      const link = `<a target="_blank" rel="noopener" href="${value}">${value}</a>`
      mirror(this.hrefTargets, link, value, valueWas)
    }
  }

  destroy() {
    if (this.hasDestroyTarget) {
      if (this.destroyTarget.value === "true") {
        this.destroyTarget.value = "false"
        this.destroyTarget.dispatchEvent(new Event("change"))
        this.element.classList.remove("is-deleted")
        this.editTarget.classList.remove("invisible")
      } else {
        this.destroyTarget.value = "true"
        this.destroyTarget.dispatchEvent(new Event("change"))
        this.element.classList.add("is-deleted")
        this.editTarget.classList.add("invisible")
      }
    } else {
      this.element.remove()
    }
  }

  modalClosed() {
    if (!this.hasDestroyTarget && !this.nameFieldTarget.value) {
      this.element.remove()
    }
  }
}
