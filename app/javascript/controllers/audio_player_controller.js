import { Controller } from "@hotwired/stimulus"
import convertSecondsToDuration from "util/convertSecondsToDuration"

export default class extends Controller {
  static targets = ["audio", "duration", "progress", "progressBar"]

  connect() {
    this.playing = false
    this.seeking = false
    this.originalDuration = this.durationTarget.innerHTML
    this.bindMouseMove = this.mouseMove.bind(this)
    this.bindMouseUp = this.mouseUp.bind(this)
  }

  disconnect() {
    window.removeEventListener("mousemove", this.bindMouseMove)
    window.removeEventListener("mouseup", this.bindMouseUp)
  }

  async play() {
    this.playing = true
    if (!this.audioTarget.duration) {
      this.setProgress(0, 1) // initial render
    }
    this.element.classList.add("prx-playing")
    this.element.classList.remove("prx-errored")

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
    const percent = this.seekProgressBar(event.x)
    this.audioTarget.currentTime = percent * this.audioTarget.duration

    this.element.classList.remove("prx-seeking")
    window.removeEventListener("mousemove", this.bindMouseMove)
    window.removeEventListener("mouseup", this.bindMouseUp)
    this.seeking = null
  }

  audioTimeUpdate() {
    this.setProgress(this.audioTarget.currentTime, this.audioTarget.duration)
  }

  audioEnded() {
    this.pause()
    this.setProgress(0, 1)
  }

  setProgress(currentTime, totalDuration) {
    if (!this.seeking) {
      this.setProgressBar(currentTime / totalDuration)
    }

    // TODO: convertSecondsToDuration is similar, but a different format
    if (this.playing) {
      const time = Math.floor(currentTime)
      const hours = String(Math.floor(time / 3600)).padStart(2, "0")
      const minutes = String(Math.floor((time % 3600) / 60)).padStart(2, "0")
      const seconds = String(time % 60).padStart(2, "0")
      if (hours === "00") {
        this.durationTarget.innerHTML = `(0:${minutes}:${seconds})`
      } else {
        this.durationTarget.innerHTML = `(${hours}:${minutes}:${seconds})`
      }
    }
  }

  setProgressBar(percent) {
    this.progressBarTarget.style.width = `${percent * 100}%`
    this.progressBarTarget.ariaValueNow = `${percent * 100}`
  }

  seekProgressBar(x) {
    const offset = Math.min(Math.max(x - this.seeking.left, 0), this.seeking.width)
    const percent = offset / this.seeking.width
    this.setProgressBar(percent)
    return percent
  }
}
