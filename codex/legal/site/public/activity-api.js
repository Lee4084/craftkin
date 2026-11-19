/* H5-owned activity bootstrap. The sample configuration below is TEST only. */
(function (root, factory) {
  if (typeof module === "object" && module.exports) module.exports = factory(require("./vendor/crypto-js-4.2.0.js"));
  else root.CraftkinActivity = factory(root.CryptoJS);
})(typeof globalThis !== "undefined" ? globalThis : this, function (CryptoJS) {
  "use strict";
  const config = Object.freeze({
    environment: "craftkin-test-v1", baseURL: "https://test-app.dirtan.work", package: "com.huankecontact.test",
    configPath: "/config/getAppConfigPostV2", authPath: "/security/oauth", strategyPath: "/config/getStrategyPostV2",
    ipTracePath: "/cdn-cgi/trace",
    messagingURL: "wss://test-im.dirtan.work", eventsURL: "https://test-log.dirtan.work",
    fields: ["R3f6s4k", "7aP9g2d", "m5T1z8b"], activityPath: "xttest", version: "1.0.2", appName: "EchoSkill"
  });
  const entryKey = "abcd1efgh2ijkl3mnop4qrst5uvwx6yz";
  const cacheKey = "craftkin.activity.entry.v2";
  const identityKey = "craftkin.activity.installation.v1";
  const legalOrigin = "https://craftkin.pages.dev";
  const testPath = new URL(config.baseURL).hostname === "test-app.dirtan.work" && config.package === "com.huankecontact.test"
    ? config.activityPath : "";
  let currentEntry = null;
  const fail = () => { throw new Error("Invalid activity response"); };
  function emit(observer, event) { try { if (typeof observer === "function") observer(event); } catch {} }
  function readableHeaders(response) {
    const result = {};
    response.headers?.forEach((value, name) => { result[name] = value; });
    return result;
  }
  function responseDetails(raw, key) {
    let responseBody = raw, responseFormat = "text";
    try {
      responseBody = key ? decode(raw, key) : JSON.parse(raw);
      responseFormat = key ? "decrypted JSON" : "JSON";
    } catch {
      try { responseBody = JSON.parse(raw); responseFormat = "JSON"; } catch {}
    }
    return { responseBody, responseFormat, responseRaw: raw };
  }
  const object = value => value && typeof value === "object" && !Array.isArray(value) ? value : fail();
  const text = value => typeof value === "string" && value.length ? value : fail();
  function base64(value) {
    const input = text(value).replace(/[\r\n]/g, "");
    if (input.length % 4 || !/^[A-Za-z0-9+/]+={0,2}$/.test(input)) fail();
    return CryptoJS.enc.Base64.parse(input);
  }
  function keyBytes(key) {
    return CryptoJS.enc.Utf8.parse(Array.from(key).slice(0, 32).join("").padEnd(32, "0"));
  }
  function encrypt(value, key) {
    return CryptoJS.AES.encrypt(typeof value === "string" ? value : JSON.stringify(value), keyBytes(key),
      { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 }).ciphertext.toString(CryptoJS.enc.Base64);
  }
  function decrypt(value, key) {
    const bytes = base64(value);
    if (bytes.sigBytes % 16) fail();
    const result = CryptoJS.AES.decrypt({ ciphertext: bytes }, keyBytes(key),
      { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.NoPadding });
    const byte = index => (result.words[index >>> 2] >>> (24 - index % 4 * 8)) & 255;
    const padding = byte(result.sigBytes - 1);
    if (padding < 1 || padding > 16 || padding > result.sigBytes) fail();
    for (let i = result.sigBytes - padding; i < result.sigBytes; i++) if (byte(i) !== padding) fail();
    result.sigBytes -= padding;
    return result.toString(CryptoJS.enc.Utf8);
  }
  function decode(value, key) { return object(JSON.parse(decrypt(value, key))); }
  function validURL(value, protocols = ["https:"]) {
    try {
      const url = new URL(value);
      if (!protocols.includes(url.protocol) || url.username || url.password || url.port || !url.hostname.includes(".") ||
          url.hostname.endsWith(".local") || url.hostname.endsWith(".localhost") ||
          /^[\d.]+$/.test(url.hostname) || url.hostname.includes(":")) return null;
      return url;
    } catch { return null; }
  }
  function read(storage, key) { try { return storage?.getItem(key); } catch { return null; } }
  function write(storage, key, value) { try { storage?.setItem(key, value); } catch {} }
  function forget(storage) { try { storage?.removeItem(cacheKey); } catch {} }
  function installation(storage, crypto) {
    const stored = read(storage, identityKey);
    if (stored && /^[a-f0-9-]{36}$/i.test(stored)) return stored;
    const created = crypto.randomUUID();
    write(storage, identityKey, created);
    return created;
  }
  function headers(context, { token = "", userID = "", area = "" } = {}) {
    const h = {
      "device-id": context.installationID, lang: context.language, model: context.model,
      time_zone: context.timeZone, device_lang: context.language, device_country: context.country,
      platform_ver: context.systemVersion, system_language: context.language, sys_lan: context.language,
      user_id: userID, ver: config.version, pkg: config.package, platform: "iOS", is_anchor: "false", sec_ver: "0",
      Authorization: token ? "Bearer " + token : "", attribution_sdk: "", attribution_sdk_ver: "", ad_id: "", ad_device_id: ""
    };
    if (area) h.rc_type = area;
    return h;
  }
  function browserContext(storage, browser = globalThis, nativeID = "") {
    const language = browser.navigator.language || "en";
    return {
      installationID: nativeID || installation(storage, browser.crypto), language: language.split("-")[0],
      country: language.split("-").slice(1).find(part => /^[A-Z]{2}$/.test(part)) || "",
      timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone || "",
      model: /iPad/.test(browser.navigator.userAgent) ? "iPad" : /iPhone/.test(browser.navigator.userAgent) ? "iPhone" : "Web",
      systemVersion: (browser.navigator.userAgent.match(/OS (\d+(?:_\d+)*)/)?.[1] || "").replace(/_/g, ".")
    };
  }
  async function prepareContext(storage, browser = globalThis) {
    const handler = browser.webkit?.messageHandlers?.privacyAndTerms;
    if (typeof handler?.postMessage !== "function") return browserContext(storage, browser);
    const candidate = read(storage, identityKey) || "";
    const valid = value => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
    const reply = await handler.postMessage({ action: "legalConsent2", installation: valid(candidate) ? candidate : "" });
    if (!valid(reply?.installation)) throw new Error("Device identity unavailable");
    // Bind cached sessions to the Keychain installation even after website storage changes.
    if (candidate && candidate !== reply.installation) { forget(storage); currentEntry = null; }
    write(storage, identityKey, reply.installation);
    return browserContext(storage, browser, reply.installation);
  }
  function pathFromSettings(settings, override = testPath) {
    const server = settings.items?.find(item => item?.name === "app_ext_data")?.data?.config_h5app_urlpath;
    const path = override || server;
    if (typeof path !== "string" || !/^[A-Za-z0-9_-]+$/.test(path)) fail();
    return path;
  }
  function entryCipher(url) {
    const [cipher, ...params] = url.search.slice(1).split("&");
    if (params.some(param => !/^cv=\d+$/.test(param)) || base64(cipher).sigBytes % 16) fail();
    return cipher;
  }
  function normalizeEntry(raw) {
    const url = validURL(raw);
    if (!url || url.origin === legalOrigin) fail();
    const path = url.pathname.match(/\/h5_web\/([A-Za-z0-9_-]+)\/$/);
    if (!path) fail();
    if (testPath && path[1] !== testPath) {
      // Keep existing test sessions when migrating the activity protocol.
      if (testPath !== "xttest" || path[1] !== "drtest") fail();
      url.pathname = url.pathname.slice(0, -(path[1].length + 1)) + testPath + "/";
    }
    const cipher = entryCipher(url);
    url.search = "?" + cipher + "&cv=2";
    return url;
  }
  function parseClientIP(raw) {
    if (typeof raw !== "string" || raw.length > 16384) fail();
    const entries = raw.split(/\r?\n/).filter(line => line.startsWith("ip="));
    if (entries.length !== 1) fail();
    const ip = entries[0].slice(3).trim();
    const octets = ip.split(".");
    if (octets.length === 4 && octets.every(part => /^(0|[1-9]\d{0,2})$/.test(part) && Number(part) <= 255)) return ip;
    if (ip.includes(":") && /^[0-9a-f:.]+$/i.test(ip)) {
      try { new URL("https://[" + ip + "]/"); return ip; } catch {}
    }
    fail();
  }
  async function fetchClientIP(request, observer) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    const started = Date.now();
    let status = null;
    const inspect = typeof observer === "function";
    const detail = inspect ? { url: config.ipTracePath, requestHeaders: {}, requestBody: null } : {};
    emit(observer, { kind: "request", phase: "start", path: config.ipTracePath, method: "GET", ...detail });
    try {
      // Cloudflare serves this same-origin endpoint directly. Never use a cached or caller-supplied IP.
      const response = await request(config.ipTracePath, {
        method: "GET", credentials: "omit", cache: "no-store", redirect: "error", signal: controller.signal
      });
      status = response.status;
      if (inspect) detail.responseHeaders = readableHeaders(response);
      if (!response.ok && !inspect) throw new Error("Client address unavailable");
      const raw = await response.text();
      if (inspect) Object.assign(detail, responseDetails(raw));
      if (!response.ok) throw new Error("Client address unavailable");
      const value = parseClientIP(raw);
      emit(observer, { kind: "request", phase: "done", path: config.ipTracePath, method: "GET", status,
        duration: Date.now() - started, outcome: "ok", ...detail });
      return value;
    } catch (error) {
      emit(observer, { kind: "request", phase: "done", path: config.ipTracePath, method: "GET", status,
        duration: Date.now() - started, outcome: "failed", ...detail,
        ...(inspect ? { error: error.name + ": " + error.message } : {}) });
      throw error;
    } finally { clearTimeout(timer); }
  }
  async function resolve({ fetch: request = globalThis.fetch, context, onEvent }) {
    const clientIP = await fetchClientIP(request, onEvent);
    async function post(path, params, h, key) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), 20000);
      const started = Date.now();
      let status = null, code = null;
      const inspect = typeof onEvent === "function";
      const requestHeaders = { "Content-Type": "application/json", "X-Forwarded-For": clientIP };
      const requestBody = { ...params, http_headers: h };
      const detail = inspect ? { url: config.baseURL + path, requestHeaders: { ...requestHeaders },
        requestBody: JSON.parse(JSON.stringify(requestBody)) } : {};
      emit(onEvent, { kind: "request", phase: "start", path, method: "POST", ...detail });
      try {
        const response = await request(config.baseURL + path, {
          method: "POST", credentials: "omit", cache: "no-store", redirect: "error", signal: controller.signal,
          headers: requestHeaders,
          body: encrypt(requestBody, key)
        });
        status = response.status;
        if (inspect) detail.responseHeaders = readableHeaders(response);
        if (!response.ok && !inspect) throw new Error("Activity service unavailable");
        const raw = await response.text();
        if (raw.length > 2000000) fail();
        if (inspect) Object.assign(detail, responseDetails(raw, key));
        if (!response.ok) throw new Error("Activity service unavailable");
        const envelope = decode(raw, key);
        code = typeof envelope.code === "number" ? envelope.code : null;
        if (envelope.code !== 0) fail();
        const data = object(envelope.data);
        emit(onEvent, { kind: "request", phase: "done", path, method: "POST", status, code,
          duration: Date.now() - started, outcome: "ok", ...detail });
        return data;
      } catch (error) {
        emit(onEvent, { kind: "request", phase: "done", path, method: "POST", status, code,
          duration: Date.now() - started, outcome: "failed", ...detail,
          ...(inspect ? { error: error.name + ": " + error.message } : {}) });
        throw error;
      } finally { clearTimeout(timer); }
    }
    const first = await post(config.configPath, { ver: 0 }, headers(context), new URL(config.baseURL).hostname);
    const [k2, k3, k4] = config.fields.map(field => text(first[field]));
    const decodedText = value => base64(value).toString(CryptoJS.enc.Utf8);
    const key = text(decodedText(k2) + decodedText(k3));
    const settings = decode(decodedText(k4), key);
    if (!Array.isArray(settings.items)) fail();
    const area = settings.items.find(item => item?.name === "rc_area_code")?.data;
    const common = { area: typeof area === "string" ? area : "" };
    const auth = await post(config.authPath, { token: context.installationID, oauthType: 4 }, headers(context, common), key);
    const token = text(auth.token);
    const id = object(auth.userInfo).userId;
    if (!(typeof id === "string" && id.length) && !(typeof id === "number" && Number.isFinite(id))) fail();
    emit(onEvent, { kind: "identity", userID: String(id) });
    const policy = await post(config.strategyPath, {}, headers(context, { ...common, token, userID: String(id) }), key);
    // Legacy field retained as the server's activity business switch, with no reviewer identification.
    emit(onEvent, { kind: "strategy", isReviewPkg: typeof policy.isReviewPkg === "boolean" ? policy.isReviewPkg : null,
      valueType: typeof policy.isReviewPkg });
    if (typeof policy.isReviewPkg !== "boolean") fail();
    if (policy.isReviewPkg) return { route: "legal", userID: String(id) };
    const path = pathFromSettings(settings);
    const domains = object(policy.data).dr;
    if (!Array.isArray(domains) || !validURL(domains[0])) fail();
    const host = validURL(domains[0]);
    if (host.search || host.hash || host.origin === legalOrigin) fail();
    const trailing = value => value ? value.replace(/\/+$/, "") + "/" : "";
    const optionalDomain = (value, protocols) => { if (!value) return ""; if (!validURL(value, protocols)) fail(); return trailing(value); };
    const payload = {
      a: context.installationID, b: token, c: config.package, d: trailing(config.baseURL),
      e: optionalDomain(domains[1] || config.messagingURL, ["https:", "wss:"]), f: optionalDomain(domains[2] || config.eventsURL),
      g: legalOrigin + "/terms", h: legalOrigin + "/privacy", i: config.version, j: config.appName,
      k: config.fields[0], l: config.fields[1], m: config.fields[2]
    };
    // The reference H5 expects raw Base64 after '?', including '+' and '='.
    const url = trailing(host.href) + "h5_web/" + path + "/?" + encrypt(payload, entryKey) + "&cv=2#/";
    const serviceID = policy.userServiceAccountId;
    const supportURL = (typeof serviceID === "string" && serviceID.length || typeof serviceID === "number" && Number.isFinite(serviceID))
      ? url.slice(0, url.indexOf("#")) + "#/pages/chat/chat?userId=" + encodeURIComponent(String(serviceID)) : "";
    return { route: "activity", url, supportURL, userID: String(id) };
  }
  function cachedEntry(storage) {
    try {
      const entry = JSON.parse(read(storage, cacheKey) || "null");
      if (entry?.environment === config.environment) {
        const url = normalizeEntry(entry.url);
        if (url.hash !== "#/") fail();
        const previousSearch = url.search;
        const payload = decode(entryCipher(url), entryKey);
        if (payload.i !== config.version) {
          payload.i = config.version;
          url.search = "?" + encrypt(payload, entryKey) + "&cv=2";
        }
        let support;
        try { support = entry.supportURL && normalizeEntry(entry.supportURL); } catch {}
        let supportURL = "";
        if (support && support.origin === url.origin && support.pathname === url.pathname &&
            support.search === previousSearch && support.hash.startsWith("#/pages/chat/chat?userId=")) {
          support.search = url.search;
          supportURL = support.href;
        }
        const result = { url: url.href, supportURL, userID: typeof entry.userID === "string" ? entry.userID : "" };
        if (entry.url !== result.url || (entry.supportURL || "") !== supportURL) {
          write(storage, cacheKey, JSON.stringify({ environment: config.environment, ...result }));
        }
        return result;
      }
    } catch {}
    forget(storage);
    return null;
  }
  function cached(storage) { return cachedEntry(storage)?.url || null; }
  function remember(storage, url, supportURL = "", userID = "") {
    currentEntry = { url, supportURL, userID };
    write(storage, cacheKey, JSON.stringify({ environment: config.environment, ...currentEntry }));
  }
  function privacyAndTerms(value, storage) {
    if (arguments.length < 2) { try { storage = globalThis.localStorage; } catch {} }
    if (typeof value !== "string" || !value.length || value.length > 8192 || /[\u0000-\u001f\u007f]/.test(value)) fail();
    const entry = currentEntry || cachedEntry(storage);
    if (!entry) fail();
    const url = normalizeEntry(entry.url);
    const payload = decode(entryCipher(url), entryKey);
    payload.b = value;
    payload.i = config.version;
    const query = encrypt(payload, entryKey);
    const update = address => {
      const target = normalizeEntry(address);
      return target.origin + target.pathname + "?" + query + "&cv=2" + target.hash;
    };
    currentEntry = { url: update(entry.url), supportURL: entry.supportURL ? update(entry.supportURL) : "", userID: entry.userID || "" };
    try { storage?.setItem(cacheKey, JSON.stringify({ environment: config.environment, ...currentEntry })); }
    catch { forget(storage); }
    return { ...currentEntry };
  }
  async function launch({ storage, context, fetch, force = false, authorize = async () => {}, navigate,
                          onEvent, beforeRoute = async () => {} }) {
    if (force) { forget(storage); currentEntry = null; }
    const previous = cachedEntry(storage);
    emit(onEvent, { kind: "cache", hit: !!previous, userID: previous?.userID || "" });
    const result = previous ? { route: "activity", ...previous } : await resolve({ fetch, context, onEvent });
    emit(onEvent, { kind: "route", route: result.route, source: previous ? "cache" : "network" });
    await beforeRoute(result);
    if (result.route === "legal") {
      forget(storage);
      currentEntry = null;
      await navigate("/terms?consent=app");
    } else {
      // Commit before native presents the activity and hides this WebView.
      remember(storage, result.url, result.supportURL, result.userID);
      try {
        await authorize(result.url, { supportURL: result.supportURL || "" });
      } catch (error) {
        if (previous) remember(storage, previous.url, previous.supportURL, previous.userID);
        else { forget(storage); currentEntry = null; }
        throw error;
      }
      await navigate(result.url);
    }
    return result.route;
  }
  return Object.freeze({ config, entryKey, cacheKey, encrypt, decrypt, decode, validURL, headers,
    browserContext, prepareContext, pathFromSettings, resolve, cached, remember, forget, launch, privacyAndTerms });
});
