import { Controller } from "@hotwired/stimulus"
import convertSecondsToDuration from "util/convertSecondsToDuration"

export default class extends Controller {
  static targets = ["audio", "duration", "progress", "progressBar"]
  static values = { offset: Number, duration: Number }

  connect() {
    this.playing = false
    this.seeking = false
    this.playbackPercent = 0
    this.originalDuration = this.durationTarget.innerHTML

    this.bindAudioLoaded = this.audioLoaded.bind(this)
    this.bindGlobalPlayback = this.globalPlayback.bind(this)
    this.bindMouseMove = this.mouseMove.bind(this)
    this.bindMouseUp = this.mouseUp.bind(this)

    this.audioTarget.addEventListener("loadeddata", this.bindAudioLoaded)
    window.addEventListener("globalPlayback", this.bindGlobalPlayback)
  }

  disconnect() {
    this.audioTarget.removeEventListener("loadeddata", this.bindAudioLoaded)
    window.removeEventListener("globalPlayback", this.bindGlobalPlayback)
    window.removeEventListener("mousemove", this.bindMouseMove)
    window.removeEventListener("mouseup", this.bindMouseUp)
  }

  async play() {
    if (this.playing) {
      return
    }

    this.playing = true
    if (!this.audioTarget.currentTime) {
      this.audioTarget.currentTime = this.offsetValue
    }
    this.setProgress()
    this.element.classList.add("prx-playing")
    this.element.classList.remove("prx-errored")

    // pause playback of other players
    const event = new Event("globalPlayback")
    event.playbackTarget = this.element
    window.dispatchEvent(event)

    try {
      await this.audioTarget.play()
    } catch (err) {
      this.element.classList.add("prx-errored")
      console.error(err)
    }
  }

  pause() {
    this.audioTarget.pause()
    this.playing = false
    this.element.classList.remove("prx-playing")
    this.durationTarget.innerHTML = this.originalDuration
  }

  audioLoaded() {
    this.setPlayback()
  }

  globalPlayback(event) {
    if (this.playing && event.playbackTarget !== this.element) {
      this.pause()
    }
  }

  mouseDown(event) {
    this.seeking = this.progressTarget.getBoundingClientRect()
    this.element.classList.add("prx-seeking")
    this.seekProgressBar(event.x)
    window.addEventListener("mousemove", this.bindMouseMove)
    window.addEventListener("mouseup", this.bindMouseUp)
  }

  mouseMove(event) {
    this.seekProgressBar(event.x)
  }

  mouseUp(event) {
    this.seekProgressBar(event.x)
    this.setPlayback()
    this.element.classList.remove("prx-seeking")
    window.removeEventListener("mousemove", this.bindMouseMove)
    window.removeEventListener("mouseup", this.bindMouseUp)
    this.seeking = null
  }

  audioTimeUpdate() {
    this.setProgress()
    if (this.playbackPercent >= 1) {
      this.audioEnded()
    }
  }

  audioEnded() {
    this.pause()
    this.setProgress()
  }

  setProgress() {
    const currentTime = (this.audioTarget.currentTime || 0) - this.offsetValue
    const totalDuration = this.durationValue || this.audioTarget.duration || 1

    if (!this.seeking) {
      this.setProgressBar(currentTime / totalDuration)
    }

    // TODO: convertSecondsToDuration is similar, but a different format
    if (this.playing) {
      const time = Math.floor(currentTime)
      const hours = String(Math.floor(time / 3600)).padStart(2, "0")
      const minutes = String(Math.floor((time % 3600) / 60)).padStart(2, "0")
      const seconds = String(time % 60).padStart(2, "0")
      this.durationTarget.innerHTML = `(${hours}:${minutes}:${seconds})`
    }
  }

  setProgressBar(percent) {
    this.playbackPercent = percent
    this.progressBarTarget.style.width = `${percent * 100}%`
    this.progressBarTarget.ariaValueNow = `${percent * 100}`
  }

  seekProgressBar(x) {
    const offset = Math.min(Math.max(x - this.seeking.left, 0), this.seeking.width)
    this.setProgressBar(offset / this.seeking.width)
    this.play()
  }

  setPlayback() {
    if (this.audioTarget.duration) {
      const offset = this.offsetValue
      const duration = this.durationValue || this.audioTarget.duration
      this.audioTarget.currentTime = offset + this.playbackPercent * duration
    }
  }
}
