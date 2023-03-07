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
pin "konva", to: "https://ga.jspm.io/npm:konva@8.4.2/lib/index.js", preload: true
pin "peaks.js", to: "https://ga.jspm.io/npm:peaks.js@3.0.0-beta.6/dist/peaks.esm.js", preload: true
pin "waveform-data", to: "https://ga.jspm.io/npm:waveform-data@4.3.0/dist/waveform-data.esm.js", preload: true
pin "konva/lib/Animation", to: "https://ga.jspm.io/npm:konva@8.4.2/lib/Animation.js", preload: true
pin "konva/lib/Core", to: "https://ga.jspm.io/npm:konva@8.4.2/lib/Core.js", preload: true
pin "konva/lib/shapes/Line", to: "https://ga.jspm.io/npm:konva@8.4.2/lib/shapes/Line.js", preload: true
pin "konva/lib/shapes/Rect", to: "https://ga.jspm.io/npm:konva@8.4.2/lib/shapes/Rect.js", preload: true
pin "konva/lib/shapes/Text", to: "https://ga.jspm.io/npm:konva@8.4.2/lib/shapes/Text.js", preload: true
pin "lodash", to: "https://ga.jspm.io/npm:lodash@4.17.21/lodash.js"

# NOTE: this one seems a bit broken, so appended `export default window.SlimSelect;` to the file
pin "slim-select", preload: true # @2.4.1

pin_all_from "app/javascript/controllers", under: "controllers"
pin_all_from "app/javascript/custom", under: "custom"
pin_all_from "app/javascript/util", under: "util"
