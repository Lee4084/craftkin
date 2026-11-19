(() => {
  "use strict";
  const retry = document.getElementById("startup-retry");
  const actions = document.getElementById("startup-actions");
  const spinner = document.getElementById("startup-spinner");
  if (!retry || !spinner) return;
  const parameters = new URLSearchParams(window.location.search);
  if (parameters.get("consent") !== "app") {
    if (actions) actions.hidden = false;
    if (spinner) spinner.hidden = true;
    return;
  }
  const api = window.CraftkinActivity;
  const debug = window.CraftkinDebug;
  let busy = false;
  async function start(force = false) {
    if (busy) return;
    busy = true;
    retry.hidden = true;
    if (actions) actions.hidden = true;
    if (spinner) spinner.hidden = false;
    if (debug?.enabled) debug.begin(api.config);
    try {
      let storage;
      try { storage = window.localStorage; } catch {}
      const handlers = window.webkit?.messageHandlers;
      const currentBridge = handlers?.privacyAndTerms;
      const bridge = currentBridge || handlers?.[["web", "Navigation"].join("")];
      let opened = false;
      const context = await api.prepareContext(storage, window);
      if (debug?.enabled) debug.context(context);
      await api.launch({
        storage, context, fetch: window.fetch.bind(window),
        force: force || parameters.get("refresh") === "1",
        onEvent: debug?.enabled ? debug.event : undefined,
        beforeRoute: async result => {
          if (!debug?.enabled) return;
          await debug.wait(result);
        },
        authorize: async (url, context) => {
          if (typeof bridge?.postMessage !== "function") return;
          const action = currentBridge ? "legalConsent1" : ["allow", "Navigation"].join("");
          const reply = await bridge.postMessage({ action, url, supportURL: context?.supportURL || "" });
          if (reply?.allowed !== true) throw new Error("Navigation unavailable");
          opened = reply.opened === true;
        },
        navigate: url => {
          if (!opened) window.location.replace(url);
        }
      });
    } catch {
      if (debug?.enabled) debug.failure();
      busy = false;
      retry.hidden = false;
      if (actions) actions.hidden = false;
      if (spinner) spinner.hidden = true;
    }
  }
  retry.addEventListener("click", () => start(true));
  start();
})();
