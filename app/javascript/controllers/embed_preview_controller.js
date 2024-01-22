import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["wrapper"]
  static values = { embedHtml: String }

  // handle changes to iframe html ourselves, to prevent flickering
  embedHtmlValueChanged(value, previousValue) {
    if (previousValue) {
      const wrapper = this.wrapperTarget
      const iframe = this.wrapperTarget.querySelector("iframe")
      const tpl = document.createElement("template")
      tpl.innerHTML = value

      if (tpl.content.firstChild.tagName === "IFRAME") {
        this.updateWrapper(wrapper, null)
        this.updateIframe(iframe, tpl.content.firstChild)
      } else {
        this.updateWrapper(wrapper, tpl.content.firstChild)
        this.updateIframe(iframe, tpl.content.firstChild.firstChild)
      }
    }
  }

  updateWrapper(wrapper, tpl) {
    if (tpl) {
      wrapper.setAttribute("style", tpl.getAttribute("style"))
    } else {
      wrapper.removeAttribute("style")
    }
  }

  updateIframe(iframe, tpl) {
    iframe.setAttribute("height", tpl.getAttribute("height"))
    iframe.setAttribute("width", tpl.getAttribute("width"))
    iframe.setAttribute("style", tpl.getAttribute("style"))

    const url = new URL(tpl.src)
    const search = new URLSearchParams(url.search)

    // TODO: would be easier if we didn't need to translate these
    const config = {
      showCoverArt: search.get("ca") === "1",
      showPlaylist: search.get("sp"),
      playlistSeason: search.get("se"),
      playlistCategory: search.get("ct"),
      theme: search.get("th"),
      accentColor: search.get("ac"),
    }
    iframe.contentWindow.postMessage(config, url.origin)
  }
}
