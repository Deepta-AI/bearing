// Progressive enhancement for the signup page.
(function () {
  var hidden = document.querySelector('input[name="plan"]');
  document.querySelectorAll(".plan").forEach(function (card) {
    function pick() {
      document.querySelectorAll(".plan").forEach(function (c) { c.classList.remove("selected"); });
      card.classList.add("selected");
      hidden.value = card.dataset.plan;
    }
    card.addEventListener("click", pick);
    card.addEventListener("keydown", function (e) {
      if (e.key === "Enter") pick();
    });
  });

  var pw = document.getElementById("password");
  var toggle = document.querySelector("[data-toggle-password]");
  toggle.addEventListener("click", function () {
    pw.type = pw.type === "password" ? "text" : "password";
  });

  var modal = document.getElementById("terms-modal");
  document.querySelector("[data-open-terms]").addEventListener("click", function (e) {
    e.preventDefault();
    modal.hidden = false;
  });
  document.querySelector("[data-close-terms]").addEventListener("click", function () {
    modal.hidden = true;
  });

  document.querySelector(".terms-text").addEventListener("click", function () {
    var box = document.getElementById("terms");
    box.checked = !box.checked;
  });
})();
