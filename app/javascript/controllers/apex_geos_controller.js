import { Controller } from "@hotwired/stimulus"
import { Loader } from "@googlemaps/js-api-loader"

export default class extends Controller {
  static values = {
    id: String,
    apiKey: String,
  }

  connect() {
    const loader = new Loader({
      apiKey: this.apiKeyValue,
      version: "weekly",
    })

    loader.load().then(async () => {
      const { Map } = await google.maps.importLibrary("maps")

      let mappp = new Map(document.getElementById(this.idValue), {
        center: { lat: -34.397, lng: 150.644 },
        zoom: 8,
      })
    })
  }
}
