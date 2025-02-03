import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template"]

  addLink(event) {
    const now = new Date().getTime()
    console.log(event.target.value)
    const platform = event.target.value
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", now).replaceAll("NEW_PLATFORM", platform)
    this.templateTarget.insertAdjacentHTML("beforeBegin", html)
  }
}
