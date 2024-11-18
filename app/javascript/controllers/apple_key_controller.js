import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["provider", "key", "pem"]

  async convertFileToKey(event) {
    const keyFile = event.target.files[0]
    const fileName = keyFile.name
    const fileText = await this.readFile(keyFile)

    this.convertFileName(fileName)
    this.convertKeyToB64(fileText)
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

  convertFileName(fileName) {
    const fields = fileName.split("_")
    const provider = fields[0]
    const keyId = fields[1].split(".")[0]

    this.providerTargets.forEach((target) => (target.value = provider))
    this.keyTargets.forEach((target) => (target.value = keyId))
  }

  convertKeyToB64(fileText) {
    const encoded = btoa(fileText)
    this.pemTarget.value = encoded
  }
}
