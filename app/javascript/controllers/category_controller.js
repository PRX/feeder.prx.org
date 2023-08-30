import { Controller } from "@hotwired/stimulus"
import Tags from "bootstrap5-tags"

export default class extends Controller {
  static targets = ["field"]

  addCategory(event) {
    const vals = Tags.getInstance(this.fieldTarget).getSelectedValues()

    if (!vals.includes(event.target.value)) {
      Tags.getInstance(this.fieldTarget).addItem(event.target.value)
    }
  }
}
