import { Controller } from "@hotwired/stimulus"
import Tags from "bootstrap5-tags"

export default class extends Controller {
  static targets = ["field"]

  addCategory(event) {
    const vals = Tags.getInstance(this.fieldTarget).getSelectedValues()

    if (!vals.includes(event.target.value)) {
      if (vals.length === 0) {
        this.fieldTarget.classList.remove("form-control-blank")
      }
      Tags.getInstance(this.fieldTarget).addItem(event.target.value)
      event.target.classList.add("btn-primary")
      event.target.classList.remove("btn-light")
    } else {
      Tags.getInstance(this.fieldTarget).removeItem(event.target.value)
      event.target.classList.add("btn-light")
      event.target.classList.remove("btn-primary")
    }
  }
}
