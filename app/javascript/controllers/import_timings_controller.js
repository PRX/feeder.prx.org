import { Controller } from "@hotwired/stimulus"
import humanBytes from "util/humanBytes"

export default class extends Controller {
  static targets = [
    "upload",
    "fakeField",
    "fileIcon",
    "fileName",
    "fileNameField",
    "fileSize",
    "paste",
    "pastedField",
    "textArea",
  ]

  showUpload(event) {
    event.preventDefault()
    this.uploadTarget.classList.remove("d-none")
    this.pasteTarget.classList.add("d-none")
    this.pastedFieldTarget.disabled = true
  }

  showPaste(event) {
    event.preventDefault()
    this.uploadTarget.classList.add("d-none")
    this.pasteTarget.classList.remove("d-none")
    this.pastedFieldTarget.disabled = false
  }

  async upload(event) {
    const file = event.currentTarget.files[0]
    if (file) {
      this.fileIconTarget.innerHTML = "description"
      this.fileNameTarget.innerHTML = file.name
      this.fileNameFieldTarget.value = file.name
      this.fileSizeTarget.innerHTML = `(${humanBytes(file.size)})`

      const text = await this.readFile(file)
      this.textAreaTarget.value = text
      this.fakeFieldTarget.classList.add("is-changed")
      this.textAreaTarget.classList.add("is-changed")
      if (text) {
        this.textAreaTarget.classList.remove("form-control-blank")
      }
    }
  }

  readFile(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.onload = (event) => resolve(event.target.result)
      reader.onerror = (error) => {
        console.error("Unable to read text file", file)
        resolve("")
      }
      reader.readAsText(file)
    })
  }
}
