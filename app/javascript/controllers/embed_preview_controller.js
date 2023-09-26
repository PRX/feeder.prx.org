import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["accentColor", "embedIframe", "embedIframeWrapper", "embedUrl", "embedHtml"]

  static values = {
    embedUrl: String,
    embedType: String,
  }

  connect() {
    const that = this
    window.addEventListener(
      "message",
      (e) => {
        that.handlePostMessage(e)
      },
      false
    )

    if (this.hasEmbedIframeTarget && this.hasEmbedUrlValue) {
      this.embedIframeTarget.setAttribute("src", this.embedUrlValue)
    }
  }

  disconnect() {
    const that = this
    window.removeEventListener(
      "message",
      (e) => {
        that.handlePostMessage(e)
      },
      false
    )
  }

  handlePostMessage(e) {
    // Bail if post message didn't originate from a Play domain.
    if (!/^https?:\/\/play(?:\.staging)?\.prx\.(?:org|tech|test)$/.test(e.origin)) return

    this.previewSource = e.source
    this.previewOrigin = e.origin

    this.updateEmbedUrlTarget(e.data.embedUrl)
    this.updateEmbedUHtmlTarget(e.data.embedHtml)
    this.updateEmbedStyles(e.data.embedStyles, e.data.embedHeight)
  }

  postConfigChange(config) {
    this.previewSource.postMessage(config, this.previewOrigin)
  }

  updateEmbedUrlTarget(embedUrl) {
    if (!embedUrl) return

    for (const elm of this.embedUrlTargets) {
      switch (elm.tagName) {
        case "INPUT":
          elm.value = embedUrl
          break

        case "A":
          elm.href = embedUrl
          break

        case "BUTTON":
          elm.setAttribute("data-clipboard-copy-value", embedUrl)
          break
      }
    }
  }

  updateEmbedUHtmlTarget(embedHtml) {
    if (!embedHtml) return

    for (const elm of this.embedHtmlTargets) {
      switch (elm.tagName) {
        case "INPUT":
          elm.value = embedHtml
          break

        case "BUTTON":
          elm.setAttribute("data-clipboard-copy-value", embedHtml)
          break
      }
    }
  }

  updateEmbedStyles(styles, height) {
    this.embedIframeTarget.removeAttribute("class")

    if (this.embedType === "card") {
      this.embedIframeTarget.setAttribute("height", "100%")
      this.embedIframeTarget.setAttribute("style", styles.iframe)
      this.embedIframeWrapperTarget.setAttribute("style", styles.wrapper)
    } else {
      this.embedIframeTarget.setAttribute("height", height)
      this.embedIframeTarget.setAttribute("style", styles.iframe)
      this.embedIframeWrapperTarget.setAttribute("style", styles.wrapper)
    }
  }

  changeType(e) {
    this.embedType = e.target.value
    this.postConfigChange({ showCoverArt: e.target.value === "card" })
  }

  changeMaxWidth(e) {
    let maxWidth = e.target.value ? parseInt(e.target.value, 10) : null

    if (maxWidth && maxWidth < e.target.min) {
      maxWidth = null
    }

    this.postConfigChange({ maxWidth })
  }

  changePlaylist(e) {
    const showPlaylist = !e.target.value ? "all" : (e.target.value > 1 && e.target.value) || null

    this.postConfigChange({ showPlaylist })
  }

  changeSeason(e) {
    this.postConfigChange({ playlistSeason: e.target.value })
  }

  changeCategory(e) {
    this.postConfigChange({ playlistCategory: e.target.value })
  }

  changeTheme(e) {
    this.postConfigChange({ theme: e.target.value !== "dark" ? e.target.value : null })
  }

  changeAccentColor(e) {
    const accentColor = e.target.value !== "#ff9600" ? [e.target.value] : null

    this.postConfigChange({ accentColor })
  }
}
