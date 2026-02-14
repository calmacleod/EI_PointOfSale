import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["emailInput", "passwordInput"]
  static values = { email: String, password: String }

  autofill(event) {
    event.preventDefault()
    if (this.hasEmailInputTarget) this.emailInputTarget.value = this.emailValue
    if (this.hasPasswordInputTarget) this.passwordInputTarget.value = this.passwordValue
  }
}
