// Pricing page behaviour. window.FLAGS is written by app/pricing/page.py.
(function () {
  var flags = window.FLAGS || {};
  if (!flags["new_pricing"]) {
    return; // legacy table has no toggle
  }
  var button = document.getElementById("billing-toggle");
  var annual = false;
  button.addEventListener("click", function () {
    annual = !annual;
    document.querySelectorAll(".price.monthly").forEach(function (el) { el.hidden = annual; });
    document.querySelectorAll(".price.annual").forEach(function (el) { el.hidden = !annual; });
    button.textContent = annual ? "Show monthly prices" : "Show annual prices";
  });
})();
