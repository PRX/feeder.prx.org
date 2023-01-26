import { Controller } from "@hotwired/stimulus"
import SlimSelect from "slim-select"

export default class extends Controller {
  static values = { groupSelect: Boolean }

  connect() {
    this.select = new SlimSelect({
      select: this.element,
      selectByGroup: this.groupSelectValue,
      placeholder: " ",
      allowDeselect: this.hasEmpty(this.element),
      showSearch: this.showSearch(this.element),
      onChange: function (info) {
        const val = Array.isArray(info) ? info.length > 0 : info.value
        if (val) {
          this.select.element.classList.remove("form-control-blank")
          this.slim.container.classList.remove("form-control-blank")
        } else {
          this.select.element.classList.add("form-control-blank")
          this.slim.container.classList.add("form-control-blank")
        }
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
