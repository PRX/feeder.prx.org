import { Controller } from "@hotwired/stimulus"

const OSM_TYPES = { N: "node", W: "way", R: "relation" }

// mirror input changes to other display-only elements (as text, since values may come from search results)
const mirror = (toElements, content, value, valueWas) => {
  toElements.forEach((el) => {
    if (!value) {
      el.textContent = "—"
    } else if (content instanceof Node) {
      el.replaceChildren(content.cloneNode(true))
    } else {
      el.textContent = content
    }

    if (valueWas !== undefined && valueWas !== value) {
      el.classList.add("is-changed")
    } else {
      el.classList.remove("is-changed")
    }
  })
}

const osmLink = (osmUrl, osm) => {
  const match = osm.match(/^([NWR])(\d+)/)
  if (!match) {
    return osm
  }
  const link = document.createElement("a")
  link.href = `${osmUrl}/${OSM_TYPES[match[1]]}/${match[2]}`
  link.target = "_blank"
  link.rel = "noopener"
  link.textContent = osm
  return link
}

export default class extends Controller {
  static targets = [
    "name",
    "nameField",
    "rel",
    "country",
    "countryField",
    "osm",
    "osmField",
    "latitudeField",
    "longitudeField",
    "query",
    "results",
    "edit",
    "destroy",
  ]
  static values = { searchUrl: String, osmUrl: String }

  change(event) {
    const el = event.currentTarget
    const value = el.value
    const valueWas = el.dataset.valueWas

    if (el.name.endsWith("[name]")) {
      mirror(this.nameTargets, value, value, valueWas)
    } else if (el.name.endsWith("[rel]")) {
      const text = el.options[el.selectedIndex].text
      mirror(this.relTargets, text, value, valueWas)
    } else if (el.name.endsWith("[country]")) {
      mirror(this.countryTargets, value, value, valueWas)
    } else if (el.name.endsWith("[osm]")) {
      mirror(this.osmTargets, osmLink(this.osmUrlValue, value), value, valueWas)
    }
  }

  search() {
    const query = this.queryTarget.value.trim()
    if (query.length < 2) {
      return
    }

    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("q", query)
    if (this.resultsTarget.src === url.toString()) {
      this.resultsTarget.reload()
    } else {
      this.resultsTarget.src = url.toString()
    }
  }

  select(event) {
    const { name, latitude, longitude, osm, country } = event.params

    if (!this.nameFieldTarget.value || this.nameFieldTarget.value === this.autoName) {
      this.autoName = String(name ?? "")
      this.setField(this.nameFieldTarget, this.autoName)
    }
    this.setField(this.latitudeFieldTarget, latitude)
    this.setField(this.longitudeFieldTarget, longitude)
    this.setField(this.osmFieldTarget, osm)
    this.setField(this.countryFieldTarget, country)

    this.resultsTarget.querySelectorAll(".active").forEach((el) => el.classList.remove("active"))
    event.currentTarget.classList.add("active")
  }

  clear() {
    this.setField(this.latitudeFieldTarget, "")
    this.setField(this.longitudeFieldTarget, "")
    this.setField(this.osmFieldTarget, "")
    this.setField(this.countryFieldTarget, "")
    this.resultsTarget.querySelectorAll(".active").forEach((el) => el.classList.remove("active"))
  }

  // keep the search box out of the form's unsaved changes
  ignore(event) {
    event.stopPropagation()
  }

  setField(el, value) {
    el.value = String(value ?? "")
    el.classList.toggle("form-control-blank", !el.value)
    el.dispatchEvent(new Event("input"))
    el.dispatchEvent(new Event("change"))
  }

  destroy() {
    if (this.hasDestroyTarget) {
      if (this.destroyTarget.value === "true") {
        this.destroyTarget.value = "false"
        this.destroyTarget.dispatchEvent(new Event("change"))
        this.element.classList.remove("is-deleted")
        this.editTarget.classList.remove("invisible")
      } else {
        this.destroyTarget.value = "true"
        this.destroyTarget.dispatchEvent(new Event("change"))
        this.element.classList.add("is-deleted")
        this.editTarget.classList.add("invisible")
      }
    } else {
      this.element.remove()
    }
  }

  modalClosed() {
    if (!this.hasDestroyTarget && !this.nameFieldTarget.value) {
      this.element.remove()
    }
  }
}
