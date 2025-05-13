import { Controller } from "@hotwired/stimulus"

const show = (elements, active) => {
  for (const el of elements) {
    if (el.classList.contains("dropdown-item")) {
      if (active) {
        el.classList.add("active")
      } else {
        el.classList.remove("active")
      }
    } else {
      if (active) {
        el.classList.remove("d-none")
      } else {
        el.classList.add("d-none")
      }
    }
  }
}

export default class extends Controller {
  static targets = ["auto", "light", "dark", "placeholder"]

  connect() {
    this.setActive()
  }

  auto() {
    localStorage.removeItem("colormode")
    if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
      document.documentElement.dataset.bsTheme = "dark"
    } else {
      document.documentElement.dataset.bsTheme = "light"
    }
    this.setActive()
  }

  dark() {
    localStorage.setItem("colormode", "dark")
    document.documentElement.dataset.bsTheme = "dark"
    this.setActive()
  }

  light() {
    localStorage.setItem("colormode", "light")
    delete document.documentElement.dataset.bsTheme
    this.setActive()
  }

  setActive() {
    const mode = localStorage.getItem("colormode")
    show(this.autoTargets, !mode)
    show(this.lightTargets, mode === "light")
    show(this.darkTargets, mode === "dark")
    show(this.placeholderTargets, false)
  }
}
