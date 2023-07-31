import { Controller } from "@hotwired/stimulus"

const CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

export default class extends Controller {
  static outlets = ["unsaved"]
  static targets = ["showPrivate", "showPublic", "template"]

  togglePrivate(event) {
    if (event.target.checked) {
      this.show(this.showPrivateTargets)
      this.hide(this.showPublicTargets)
    } else {
      this.hide(this.showPrivateTargets)
      this.show(this.showPublicTargets)
    }
  }

  show(elements) {
    for (const el of elements) {
      el.classList.remove("d-none")
    }
  }

  hide(elements) {
    for (const el of elements) {
      el.classList.add("d-none")
    }
  }

  addToken() {
    const now = new Date().getTime()
    const token = this.randomString(24)
    const html = this.templateTarget.innerHTML.replaceAll("NEW_RECORD", now).replace("NEW_TOKEN", token)
    this.templateTarget.insertAdjacentHTML("beforeBegin", html)
    this.unsavedOutlet.change()
  }

  removeToken(event) {
    const container = event.currentTarget.parentElement
    container.classList.add("d-none")

    const destroy = container.querySelector("input[name*='_destroy']")
    destroy.value = true
    this.unsavedOutlet.change({ target: destroy })
  }

  nukeToken(event) {
    event.currentTarget.parentElement.remove()
    this.unsavedOutlet.change()
  }

  randomString(len) {
    const randoms = crypto.getRandomValues(new Uint32Array(len))
    let str = ""
    randoms.forEach((num) => (str += CHARS.charAt(num % CHARS.length)))
    return str
  }
}
