import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["template"]

  addLink(event) {
    const now = new Date().getTime()
    const platform = event.target.dataset.platform

    const template = this.templateTargets.filter((target) => {
      return target.dataset.platform === platform
    })
    const html = template[0].innerHTML.replaceAll("NEW_RECORD", now)
    this.templateTarget.insertAdjacentHTML("beforeBegin", html)
  }
}
