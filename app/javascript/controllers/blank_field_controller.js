import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  blur(event) {
    if (event.target.value) {
      event.target.classList.remove("form-control-blank")
    } else {
      event.target.classList.add("form-control-blank")
    }
  }
}
