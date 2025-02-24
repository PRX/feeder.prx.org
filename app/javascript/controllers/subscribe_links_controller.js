import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static outlets = ["unsaved"]
  static targets = ["template", "option"]

  addLink(event) {
    const now = new Date().getTime()
    const platform = event.target.dataset.platform

    const template = this.templateTargets.filter((target) => {
      return target.dataset.platform === platform
    })
    const html = template[0].innerHTML.replaceAll("NEW_RECORD", now).replaceAll("NEW_EXTERNAL_ID", "")
    this.templateTarget.insertAdjacentHTML("beforeBegin", html)
    this.unsavedOutlet.change()
    event.target.classList.add("d-none")
  }

  removeLink(event) {
    const container = event.currentTarget.parentElement
    container.classList.add("d-none")

    const destroy = container.querySelector("input[name*='_destroy']")
    destroy.value = true
    this.unsavedOutlet.change({ target: destroy })
  }

  nukeLink(event) {
    const platform = event.currentTarget.dataset.platform
    const option = this.optionTargets.filter((target) => {
      return target.dataset.platform === platform
    })
    option[0].classList.remove("d-none")

    event.currentTarget.parentElement.remove()
    this.unsavedOutlet.change()
  }
}
