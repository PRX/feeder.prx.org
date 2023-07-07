import { Controller } from "@hotwired/stimulus"
import Highcharts from "highcharts"

const CONFIG = {
  chart: { type: "line" },
  legend: { enabled: false },
  title: { text: null },
  yAxis: { title: "Downloads", min: 0, max: 100 },
  xAxis: {
    type: "datetime",
    dateTimeLabelFormats: {
      day: "%Y-%m-%d",
      week: "%Y-%m-%d",
      month: "%Y-%m-%d",
      year: "%Y-%m-%d",
    },
    labels: {
      rotation: -45,
    },
  },
}

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
    const data = this.datesValue.map((d) => ({ x: new Date(d).getTime(), y: 0 }))
    const empty = { type: "line", data }

    // setup initial/blank series for episodes and podcast
    CONFIG.series = this.titlesValue.map((name) => ({ ...empty, name }))
    CONFIG.series.push({ ...empty, name: "Total Downloads" })
    this.chart = Highcharts.chart(this.chartTarget, CONFIG)

    // load podcast/episode downloads from castle
    const query = `interval=DAY&from=${this.datesValue[0]}`
    this.load(`podcasts/${this.podcastValue}/downloads?${query}`, this.chart.series.length - 1, true)
    this.guidsValue.forEach((guid, index) => {
      this.load(`episodes/${guid}/downloads?${query}`, index)
    })
  }

  async load(path, seriesIndex, isTotal = false) {
    const json = await this.fetchJSON(path)
    if (!json) {
      return
    }
    const data = json.downloads.map((d) => [new Date(d[0]).getTime(), d[1]])

    // clear out yAxis max and update series
    this.chart.yAxis[0].update({ max: null }, false)
    this.chart.series[seriesIndex].setData(data, false)
    this.chart.redraw()

    // set total element
    if (isTotal) {
      const total = data.map((d) => d[1]).reduce((a, b) => a + b, 0)
      this.totalTarget.innerHTML = total.toLocaleString()
    }
  }

  fetchJSON(path, token = null) {
    const url = `${this.castleValue}/${path}`
    const headers = new Headers()
    headers.append("Accept", "application/json")
    headers.append("Authorization", `Bearer ${this.jwtValue}`)
    return fetch(url, { headers }).then(
      (res) => {
        if (res.status === 200) {
          return res.json()
        } else {
          const err = new Error(`Got ${res.status} from ${url}`)
          console.error(err.message, err)
          this.showError(err)
        }
      },
      (err) => {
        console.error(`Fetch error for ${url}`, err)
        if (window.location.href.includes("localhost") || window.location.href.includes("127.0.0.1")) {
          this.showError(
            new Error("CORS error - you cannot load metrics data using localhost. Switch to https://feeder.prx.test!")
          )
        } else {
          this.showError(err)
        }
      }
    )
  }

  showError(err) {
    this.chartTarget.innerHTML = `
      <div class="alert alert-danger" role="alert">
        <h3 class="alert-heading">Error</h3>
        <hr>
        <p class="mb-0">${err.message}</p>
      </div>
    `
  }
}
