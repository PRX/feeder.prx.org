import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.bindBeforeFrameRender = this.beforeFrameRender.bind(this)

    const frame = this.element.closest("turbo-frame")
    if (frame) {
      frame.addEventListener("turbo:before-frame-render", this.bindBeforeFrameRender)
    }
  }

  disconnect() {
    this.element.removeEventListener("turbo:before-frame-render", this.bindBeforeFrameRender)
  }

  beforeFrameRender(event) {
    for (const el of event.detail.newFrame.querySelectorAll('[data-controller="active-link"]')) {
      if ((el.href || "").endsWith(window.location.pathname)) {
        el.classList.add("active")
      } else {
        el.classList.remove("active")
      }
    }
  }
}
