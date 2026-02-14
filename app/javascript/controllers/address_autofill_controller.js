import { Controller } from "@hotwired/stimulus"

// Integrates Mapbox Address Autofill for address input fields.
// Set data-controller="address-autofill" and data-address-autofill-token-value="pk.xxx"
// on the form. Form inputs must have autocomplete attributes and matching data targets.
export default class extends Controller {
  static values = {
    token: String
  }

  static targets = [
    "addressLine1",
    "addressLine2",
    "city",
    "province",
    "postalCode",
    "country"
  ]

  connect() {
    if (!this.tokenValue) return
    this.loadMapbox()
  }

  loadMapbox() {
    if (window.mapboxsearch) {
      this.initAutofill()
      return
    }
    const script = document.createElement("script")
    script.src = "https://api.mapbox.com/search-js/v1.5.0/web.js"
    script.defer = true
    script.onload = () => this.initAutofill()
    document.head.appendChild(script)
  }

  initAutofill() {
    const autofill = window.mapboxsearch.autofill({
      accessToken: this.tokenValue,
      options: { country: "ca" }
    })

    // Mapbox may wrap inputs in a way that breaks form submission. Explicitly
    // copy selected values to our form inputs on retrieve.
    autofill.addEventListener("retrieve", (event) => {
      const feature = event.detail?.features?.[0]
      const props = feature?.properties ?? {}
      if (!feature) return

      const set = (target, value) => {
        if (target && value != null && String(value).trim() !== "") target.value = String(value).trim()
      }

      if (this.hasAddressLine1Target) set(this.addressLine1Target, props.address_line1 ?? props.address_line_1 ?? props.full_address)
      if (this.hasAddressLine2Target) set(this.addressLine2Target, props.address_line2 ?? props.address_line_2)
      if (this.hasCityTarget) set(this.cityTarget, props.place ?? props.address_level2 ?? props.locality)
      if (this.hasProvinceTarget) set(this.provinceTarget, props.region ?? props.address_level1)
      if (this.hasPostalCodeTarget) set(this.postalCodeTarget, props.postcode ?? props.postal_code)
      if (this.hasCountryTarget) set(this.countryTarget, props.country ?? props.country_name)
    })
  }
}
