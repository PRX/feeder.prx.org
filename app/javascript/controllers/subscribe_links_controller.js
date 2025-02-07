import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["unsaved"]
  static targets = ["template", "apple", "applefill"]

  addLink(event) {
    const now = new Date().getTime()
    const platform = event.target.dataset.platform

    const template = this.templateTargets.filter((target) => {
      return target.dataset.platform === platform
    })
    const html = template[0].innerHTML.replaceAll("NEW_RECORD", now)
    this.templateTarget.insertAdjacentHTML("beforeBegin", html)
  }

  removeLink(event) {
    const container = event.currentTarget.parentElement
    container.classList.add("d-none")

    const destroy = container.querySelector("input[name*='_destroy']")
    destroy.value = true
    this.unsavedOutlet.change({ target: destroy })
  }

  nukeLink(event) {
    event.currentTarget.parentElement.remove()
    this.unsavedOutlet.change()
  }

  populateApple() {
    this.applefillTargets.forEach((target) => {
      target.value = this.appleTarget.value
      target.classList.remove("form-control-blank")
    })
  }
}
