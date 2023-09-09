import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { copy: String, tooltip: String }

  originalStyleDisplay

  connect() {
    this.originalStyleDisplay = this.element.style.display;

    navigator.permissions.query({ name: 'clipboard-write'}).then((result) => {
      this.updatePermissionState(result.state);
      result.addEventListener('change', () => {
        this.updatePermissionState(result.state);
      })
    })

    this.element.dataset.action = "clipboard#copy"
    this.tip = new bootstrap.Tooltip(this.element, { title: this.tooltipValue })
    this.tip.disable()
  }

  disconnect() {
    this.tip.dispose()
  }

  updatePermissionState(state) {
    switch (state) {
      case 'denied':
        this.element.style.display = 'none';
        break;
      case 'prompt':
        this.element.style.display = this.originalStyleDisplay;
        break;
    }
  }

  async copy(event) {
    event.preventDefault()

    await navigator.clipboard.writeText(this.copyValue)

    // briefly show "copied" tooltip
    this.tip.enable()
    this.tip.show()
    setTimeout(() => {
      this.tip.hide()
      this.tip.disable()
    }, 1000)
  }
}
