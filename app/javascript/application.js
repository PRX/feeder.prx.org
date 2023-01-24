// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "popper"
import "bootstrap"

// debugging turbo
document.addEventListener("turbo:frame-missing", function (event) {
  alert("FRAME MISSING!!!!!!!!!!!!!")
  // event.detail.response.text().then(
  //   text => console.log('GOT TEXT:', text),
  //   err => console.log('GOT ERR:', err)
  // )
})

// prevent flickering toasts in the turbo cache
document.addEventListener("turbo:before-cache", function () {
  const toasts = document.getElementById("toast-alerts")
  if (toasts) {
    toasts.innerHTML = ""
  }
})
