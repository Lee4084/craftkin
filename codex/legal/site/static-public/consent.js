(() => {
  "use strict";

  const mode = new URLSearchParams(window.location.search).get("consent");
  const bridge = window.webkit?.messageHandlers?.legalConsent;
  if (mode !== "app" || typeof bridge?.postMessage !== "function") return;

  // Keep first-launch context when moving between the two policies and legal home.
  for (const link of document.querySelectorAll("a[href]")) {
    const target = new URL(link.getAttribute("href"), window.location.href);
    if (target.origin === window.location.origin && target.protocol === window.location.protocol) {
      target.searchParams.set("consent", "app");
      link.href = target.href;
    }
  }

  const panel = document.getElementById("app-consent");
  const button = document.getElementById("legal-agree-continue");
  const status = document.getElementById("consent-status");
  if (!panel || !button || !status) return;
  panel.hidden = false;
  const actions = panel.querySelector(".consent-actions");
  if (actions) {
    document.documentElement.classList.add("has-consent-bar");
    const measure = () => document.documentElement.style.setProperty("--consent-bar-height",
      Math.ceil(actions.getBoundingClientRect().height) + "px");
    measure();
    if (typeof ResizeObserver === "function") new ResizeObserver(measure).observe(actions);
    else window.addEventListener("resize", measure);
  }

  let pending = false;
  button.addEventListener("click", async (event) => {
    if (!event.isTrusted || pending) return;
    pending = true;
    button.disabled = true;
    status.hidden = true;
    try {
      const reply = await bridge.postMessage({ action: "agree", version: panel.dataset.consentVersion });
      if (reply?.accepted !== true) throw new Error("Acceptance was not confirmed");
    } catch {
      pending = false;
      button.disabled = false;
      status.textContent = "Couldn’t continue. Please try again.";
      status.hidden = false;
    }
  });
})();
