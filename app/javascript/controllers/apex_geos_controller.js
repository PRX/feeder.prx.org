import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: String,
    apiKey: String,
    data: Array,
  }

  connect() {
    google.charts.load("current", {
      packages: ["geochart"],
    })
    google.charts.setOnLoadCallback(this.drawRegionsMap.bind(this))
  }

  mapGeosByRegion() {
    let headers = [["State", "Count"]]
    let values = this.dataValue.map((geo) => {
      let geoCode = `${geo.country_code}-${geo.subdiv_code}`

      return [geoCode, geo.count]
    })

    return headers.concat(values)
  }

  drawRegionsMap() {
    var data = google.visualization.arrayToDataTable(this.mapGeosByRegion())

    var options = {
      region: "US",
      resolution: "provinces",
    }

    var chart = new google.visualization.GeoChart(document.getElementById(this.idValue))

    chart.draw(data, options)
  }
}
