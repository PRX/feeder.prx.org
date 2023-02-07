// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
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
