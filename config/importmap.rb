# Pin npm packages by running ./bin/importmap

pin "application", preload: true

pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "@rails/ujs", to: "@rails--ujs.js", preload: true # @7.0.4

pin "popper", to: "popper.js", preload: true
pin "bootstrap", to: "bootstrap.min.js", preload: true
pin "flatpickr", preload: true # @4.6.13
pin "bootstrap5-tags", preload: true # @1.5.4

# NOTE: this one seems a bit broken, so appended `export default window.SlimSelect;` to the file
pin "slim-select", preload: true # @2.4.1

pin_all_from "app/javascript/controllers", under: "controllers"

