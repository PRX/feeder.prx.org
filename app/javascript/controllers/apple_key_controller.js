import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["key", "pem"]

  async convertFileToKey(event) {
    const keyFile = event.target.files[0]
    let fileText = await this.readFile(keyFile)
    let keyText = this.parseKey(fileText)

    this.keyTarget.value = keyText
    this.convertKeyToB64()
  }

  convertKeyToB64() {
    let encoded = btoa(this.keyTarget.value)
    this.pemTarget.value = encoded
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

  parseKey(text) {
    const strings = text.split("\n")
    // remove "begin key" and "end key" text
    strings.shift()
    strings.pop()

    return strings.join("")
  }
}
