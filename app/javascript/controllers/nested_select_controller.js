import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // child select to updated
  static targets = ["select"]

  // map of parent select values
  static values = { opts: Object }

  // change child select options when parent selection changes
  change(event) {
    if (this.reordering) {
      return
    }

    // lookup parent selections
    const select = event.currentTarget
    const selected = select.slim.getSelected()

    // lookup child options, sorted in order of parent select
    const childOpts = selected.map((o) => this.optsValue[o] || []).flat()
    const childData = childOpts.map((o) => ({ text: o }))
    const childSelected = this.selectTarget.slim.getSelected()
    this.selectTarget.slim.setData(childData)
    this.selectTarget.slim.setSelected(childSelected)

    // reorder parent select out-of-band with this event
    setTimeout(() => this.reorder(select), 1)
  }

  reorder(select) {
    const data = select.slim.getData()
    const selected = data.filter((d) => d.selected)
    const rest = data.filter((d) => !d.selected).sort((a, b) => a.value.localeCompare(b.value))

    // disable change event while reordering, to prevent recursion
    this.reordering = true
    select.slim.setData(selected.concat(rest))
    this.reordering = false
  }
}
