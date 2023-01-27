import { Controller } from "@hotwired/stimulus"
import SlimSelect from "slim-select"

export default class extends Controller {
  static values = { groupSelect: Boolean }

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
