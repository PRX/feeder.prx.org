import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  selectDay(event) {
    console.log(event.params["day"])
  }

  selectWeek(event) {
    console.log(event.params["week"])
  }
}
