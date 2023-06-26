// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import Trix from "trix"
import "popper"
import "bootstrap"
import Rails from "@rails/ujs"

Rails.start()

// debugging turbo
document.addEventListener("turbo:frame-missing", function (event) {
  alert("FRAME MISSING!!!!!!!!!!!!!")
  // event.detail.response.text().then(
  //   text => console.log('GOT TEXT:', text),
  //   err => console.log('GOT ERR:', err)
  // )
})

// prevent flickering in the turbo cache
document.addEventListener("turbo:before-cache", function () {
  const toasts = document.getElementById("toast-alerts")
  if (toasts) {
    toasts.innerHTML = ""
  }

  const changed = document.getElementsByClassName("is-changed")
  for (const el of changed) {
    el.classList.remove("is-changed")
  }
})

document.addEventListener("trix-file-accept", (event) => {
  event.preventDefault()
})

// https://github.com/lnu-norge/lokaler.lnu.no/pull/26/files
// Set the default heading button to be h3, as we dont ever
// want someone to create h1s in Trix inside Spaces (at least for now):
// Might have to rethink this and add h2, h3 as separate buttons
// if we ever use Trix for a full page.
Trix.config.blockAttributes.heading1.tagName = "h3"

// Add p tags:
Trix.config.blockAttributes.default.tagName = "p"
Trix.config.blockAttributes.default.breakOnReturn = true

// P tag logic:
// Found at https://github.com/basecamp/trix/issues/680#issuecomment-735742942
Trix.Block.prototype.breaksOnReturn = function () {
  const attr = this.getLastAttribute()
  const config = Trix.config.blockAttributes[attr ? attr : "default"]
  return config ? config.breakOnReturn : false
}
Trix.LineBreakInsertion.prototype.shouldInsertBlockBreak = function () {
  if (this.block.hasAttributes() && this.block.isListItem() && !this.block.isEmpty()) {
    return this.startLocation.offset > 0
  } else {
    return !this.shouldBreakFormattedBlock() ? this.breaksOnReturn : false
  }
}
