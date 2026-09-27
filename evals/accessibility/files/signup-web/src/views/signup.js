import { layout } from "./layout.js";

const esc = (s = "") =>
  String(s).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);

const err = (errors, key) => (errors[key] ? `<p class="error">${errors[key]}</p>` : "");

const PLAN_CARDS = [
  { id: "solo", name: "Solo", price: "Free" },
  { id: "team", name: "Team", price: "$8 per seat" },
  { id: "business", name: "Business", price: "$15 per seat" },
];

export function signupPage({ values = {}, errors = {} } = {}) {
  const plan = values.plan || "";
  const body = `
<h1>Create your account</h1>
<form method="post" action="/signup" class="signup" novalidate>
  <div class="field">
    <input name="name" type="text" placeholder="Full name" value="${esc(values.name)}">
    ${err(errors, "name")}
  </div>
  <div class="field">
    <!-- tabindex 1 so the email field is focused first -->
    <input name="email" type="email" placeholder="Work email" tabindex="1" value="${esc(values.email)}">
    ${err(errors, "email")}
  </div>
  <div class="field password">
    <input name="password" type="password" placeholder="Password" id="password">
    <button type="button" class="icon-btn" data-toggle-password>
      <svg width="16" height="16" viewBox="0 0 16 16"><path d="M1 8s3-5 7-5 7 5 7 5-3 5-7 5-7-5-7-5z"/></svg>
    </button>
    <p class="hint">At least 12 characters</p>
    ${err(errors, "password")}
  </div>
  <div class="plans">
    <span class="plans-title">Plan</span>
    ${PLAN_CARDS.map(
      (p) => `<div class="plan${plan === p.id ? " selected" : ""}" data-plan="${p.id}" tabindex="0">
      <strong>${p.name}</strong><span class="price">${p.price}</span>
    </div>`
    ).join("\n    ")}
    <input type="hidden" name="plan" value="${esc(plan)}">
    ${err(errors, "plan")}
  </div>
  <div class="field terms">
    <input type="checkbox" name="terms" id="terms"${values.terms === "on" ? " checked" : ""}>
    <span class="terms-text">I agree to the terms of service</span>
    <a href="#" data-open-terms>Read the terms</a>
    ${err(errors, "terms")}
  </div>
  <button type="submit" class="primary" aria-label="Submit form">Create account</button>
</form>
<div class="modal" id="terms-modal" hidden>
  <div class="modal-box">
    <button type="button" class="close" data-close-terms>&times;</button>
    <h2>Terms of service</h2>
    <p>By creating an account you agree to pay for the seats you add and to keep your login details private.</p>
  </div>
</div>`;
  return layout({ title: "Sign up", body, scripts: ["/public/signup.js"] });
}
