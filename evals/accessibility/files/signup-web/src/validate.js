const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
export const PLANS = ["solo", "team", "business"];

export function validateSignup(form) {
  const errors = {};
  if (!form.name || !form.name.trim()) errors.name = "Enter your full name";
  if (!EMAIL.test(form.email || "")) errors.email = "Enter a valid email address";
  if ((form.password || "").length < 12) errors.password = "Use at least 12 characters";
  if (!PLANS.includes(form.plan)) errors.plan = "Choose a plan";
  if (form.terms !== "on") errors.terms = "Accept the terms to continue";
  return errors;
}
