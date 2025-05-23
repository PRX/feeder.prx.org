import { Controller } from "@hotwired/stimulus"
import Evaporate from "evaporate"
import SparkMD5 from "spark-md5"
import sha256 from "sha256"
import humanBytes from "util/humanBytes"

export default class extends Controller {
  static values = { fileSizeError: String }
  static outlets = ["disable"]
  static targets = [
    "field",
    "originalUrl",
    "replace",
    "fileName",
    "fileSize",
    "fileType",
    "picker",
    "progress",
    "progressBar",
    "progressBytes",
    "progressPercent",
    "success",
    "error",
    "errorMessage",
    "nonMp3Warning",
  ]

  connect() {
    this.uploadBucketName = this.getMeta("upload_bucket_name")
    this.uploadBucketPrefix = this.getMeta("upload_bucket_prefix")
    this.uploadS3EndpointHost = this.getMeta("upload_s3_endpoint_host")
    this.uploadSigningServiceKeyId = this.getMeta("upload_signing_service_key_id")
    this.uploadSigningServiceUrl = this.getMeta("upload_signing_service_url")
  }

  upload(event) {
    const file = event.target.files[0]
    if (this.hasNonMp3WarningTarget && file.type !== "audio/mpeg") {
      this.modal = new bootstrap.Modal(this.nonMp3WarningTarget)
      this.modal.show()
    } else if (file.size >= 1024 * 1024 * 1024) {
      this.fileNameTargets.forEach((t) => (t.innerHTML = file.name))
      this.fileSizeTargets.forEach((t) => (t.innerHTML = humanBytes(file.size)))
      this.onError(this.fileSizeErrorValue)
    } else {
      this.uploadFile(file)
    }
  }

  modalCancel() {
    this.modal.hide()
    this.cancelUpload()
  }

  modalContinue() {
    this.modal.hide()
    this.uploadFile(this.fieldTarget.files[0])
  }

  async uploadFile(file) {
    const config = this.getUploadConfig(file)
    try {
      this.evaporate = this.evaporate || (await this.getEvaporate())
      this.startUpload(config)
      const path = await this.evaporate.add(config)
      this.originalUrlTarget.value = `s3://${this.uploadBucketName}/${path}`
      this.show("success")
    } catch (err) {
      if (!`${err}`.includes("aborted")) {
        console.log(err)
        this.errorMessageTargets.forEach((t) => (t.innerHTML = err.message || `${err}`))
        this.show("error")
      }
    }
  }

  getUploadConfig(file) {
    const contentType = file.type || this.guessMimeType(file.name) || null
    const fileName = file.name || "(unknown)"
    const cleanName = fileName.replace(/^.*(\\|\/)/gi, "").replace(/[^A-Za-z0-9\.\-]/gi, "_")
    const name = this.addPrefix(cleanName)
    const notSignedHeadersAtInitiate = { "Content-Disposition": `attachment; filename=${cleanName}` }
    const progress = this.onProgress.bind(this)
    const error = this.onError.bind(this)

    return { name, file, cleanName, contentType, notSignedHeadersAtInitiate, progress, error }
  }

  getEvaporate() {
    if (!this.uploadBucketName) {
      alert("uploading not configured - missing UPLOAD_BUCKET_NAME")
    }
    if (!this.uploadSigningServiceKeyId) {
      alert("uploading not configured - missing UPLOAD_SIGNING_SERVICE_KEY_ID")
    }
    if (!this.uploadSigningServiceUrl) {
      alert("uploading not configured - missing UPLOAD_SIGNING_URL")
    }

    return Evaporate.create({
      aws_key: this.uploadSigningServiceKeyId,
      aws_url: this.uploadS3EndpointHost ? `https://${this.uploadS3EndpointHost}` : undefined,
      bucket: this.uploadBucketName,
      cloudfront: !!this.uploadS3EndpointHost,
      computeContentMd5: true,
      cryptoHexEncodedHash256: sha256,
      cryptoMd5Method: (data) => btoa(SparkMD5.ArrayBuffer.hash(data, true)),
      logging: false,
      onlyRetryForSameFileName: true,
      signerUrl: this.uploadSigningServiceUrl,
    })
  }

  onProgress(percent, speed) {
    const bytes = speed ? speed.totalUploaded : 0
    this.progressBarTargets.forEach((t) => {
      t.style.width = `${percent * 100}%`
      t.ariaValueNow = `${percent * 100}`
    })
    this.progressBytesTargets.forEach((t) => (t.innerHTML = percent >= 0.1 ? humanBytes(bytes) : ""))
    this.progressPercentTargets.forEach((t) => (t.innerHTML = `${percent & 100}%`))
  }

  onError(err) {
    this.errorMessageTargets.forEach((t) => (t.innerHTML = err.message || `${err}`))
    this.show("error")
  }

  startUpload(config) {
    this.fileNameTargets.forEach((t) => (t.innerHTML = config.cleanName))
    this.fileSizeTargets.forEach((t) => {
      if (t.value === undefined) {
        t.innerHTML = humanBytes(config.file.size)
      } else {
        t.value = config.file.size
      }
    })
    this.fileTypeTargets.forEach((t) => (t.innerHTML = config.contentType))

    this.onProgress(0)
    this.show("progress")
  }

  async cancelUpload(event) {
    if (event) {
      event.preventDefault()
    }

    // safely attempt to cancel
    if (this.evaporate) {
      try {
        await this.evaporate.cancel()
      } catch (err) {
        if (!`${err}`.includes("No files")) {
          console.error(err)
        }
      }
    }

    this.show("picker")
    this.fieldTarget.value = ""
    this.fieldTarget.dispatchEvent(new Event("change"))
  }

  show(type) {
    const toggle = (arr, show) =>
      arr.forEach((el) => (show ? el.classList.remove("d-none") : el.classList.add("d-none")))

    toggle(this.pickerTargets, type === "picker")
    toggle(this.progressTargets, type === "progress")
    toggle(this.successTargets, type === "success")
    toggle(this.errorTargets, type === "error")

    // disable form submit while upload in progress
    this.disableOutlet.uploading(type === "progress")

    // disable id/_destroy fields if we're replacing that file
    this.replaceTargets.forEach((el) => (el.disabled = type === "success"))
  }

  getMeta(name) {
    const el = document.head.querySelector(`meta[name=${name}]`)
    return el ? el.content : null
  }

  addPrefix(name) {
    const prefixNoSlashes = (this.uploadBucketPrefix || "").replace(/^\/|\/$/g, "")
    const date = new Date().toISOString().substr(0, 10)
    const uuid = crypto.randomUUID()
    if (prefixNoSlashes) {
      return `${prefixNoSlashes}/${date}/${uuid}/${name}`
    } else {
      return `${date}/${uuid}/${name}`
    }
  }

  guessMimeType(name) {
    const ext = (name || "").split(".").pop()
    return {
      aif: "audio/x-aiff",
      aifc: "audio/x-aiff",
      aiff: "audio/x-aiff",
      caf: "audio/x-caf",
      flac: "audio/x-flac",
      m2a: "audio/mpeg",
      m3a: "audio/mpeg",
      m4a: "audio/mp4",
      mp2: "audio/mpeg",
      mp2a: "audio/mpeg",
      mp3: "audio/mpeg",
      mp4: "video/mp4",
      mp4a: "audio/mp4",
      mpga: "audio/mpeg",
      oga: "audio/ogg",
      ogg: "audio/ogg",
      spx: "audio/ogg",
      wav: "audio/x-wav",
      weba: "audio/webm",
      gif: "image/gif",
      jpe: "image/jpeg",
      jpeg: "image/jpeg",
      jpg: "image/jpeg",
      png: "image/png",
      svg: "image/svg+xml",
      svgz: "image/svg+xml",
      webp: "image/webp",
    }[ext]
  }
}
