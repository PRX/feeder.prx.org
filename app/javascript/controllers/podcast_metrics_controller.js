import { Controller } from "@hotwired/stimulus"
import Highcharts from "highcharts"

export default class extends Controller {
  static targets = ["chart", "total"]
  static values = {
    castle: String,
    dates: Array,
    guids: Array,
    jwt: String,
    podcast: Number,
    titles: Array,
  }

  connect() {
    // Highcharts.chart(this.element, this.configValue)

    const from = this.datesValue[0]
    this.chart(`podcasts/${this.podcastValue}?interval=DAY&from=${from}`)
  }

  async chart(path) {
    console.log("charting", path)
    const json = await this.fetchJSON(path)
  }

  fetchJSON(path, token = null) {
    const url = `${this.castleValue}/${path}`
    const headers = new Headers()
    headers.append("Accept", "application/json")
    headers.append("Authorization", `Bearer ${this.jwtValue}`)
    return fetch(url, { headers }).then((res) => {
      if (res.status === 200) {
        return res.json()
      } else {
        console.error(`Failed to load ${url}`, res)
        return null
      }
    })
  }
}
