(() => {
  "use strict";
  const enabled = new URLSearchParams(window.location.search).get("debug") === "1";
  if (!enabled) { window.CraftkinDebug = Object.freeze({ enabled: false }); return; }
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = "/debug.css?v=request-details-2";
  document.head.appendChild(link);
  const panel = document.createElement("aside");
  panel.className = "debug-window";
  panel.id = "craftkin-debug";
  panel.setAttribute("aria-label", "H5 调试窗口");
  panel.innerHTML = `
    <header class="debug-header"><strong>H5 调试窗口</strong><button id="debug-minimize" type="button" aria-expanded="true">收起</button></header>
    <div id="debug-body" class="debug-body">
      <p class="debug-hint">仅 debug=1 启用。点击请求展开 Header / Response；详情仅保留在当前页内存。</p>
      <dl class="debug-config"><dt>接口</dt><dd id="debug-api">—</dd><dt>包 / 版本</dt><dd id="debug-package">—</dd>
        <dt>活动缓存</dt><dd id="debug-cache">等待检查</dd><dt>isReviewPkg</dt><dd id="debug-policy">尚未请求</dd>
        <dt>分流结果</dt><dd id="debug-route">等待结果</dd></dl>
      <label class="debug-label" for="debug-user">User ID</label>
      <div class="debug-copy-row"><input id="debug-user" readonly placeholder="等待 auth 返回" aria-label="User ID"><button id="debug-copy-user" type="button">复制</button></div>
      <label class="debug-label" for="debug-device">Device ID</label>
      <div class="debug-copy-row"><input id="debug-device" readonly placeholder="等待设备标识" aria-label="Device ID"><button id="debug-copy-device" type="button">复制</button></div>
      <div class="debug-section-title"><strong>网络请求</strong><button id="debug-copy-summary" type="button">复制摘要</button></div>
      <p id="debug-empty" class="debug-hint">等待请求。命中活动缓存时不会调用业务接口。</p>
      <ol id="debug-requests" class="debug-requests" aria-label="网络请求记录"></ol>
      <p id="debug-error" class="debug-error" hidden>启动未完成，请查看失败的请求。可清活动缓存后重新请求。</p>
      <div class="debug-actions"><button id="debug-refresh" type="button" disabled>清活动缓存并重请求</button><button id="debug-continue" type="button" disabled>继续</button></div>
      <p id="debug-message" class="debug-hint" role="status" aria-live="polite"></p>
    </div>`;
  document.body.appendChild(panel);
  const get = id => panel.querySelector("#debug-" + id);
  const state = { config: {}, userID: "", deviceID: "", cache: "等待检查", policy: "尚未请求", route: "等待结果", requests: [] };
  let resume = null;
  function display(name, text) { get(name).textContent = text; }
  function identity(userID) {
    state.userID = typeof userID === "string" ? userID : "";
    get("user").value = state.userID;
  }
  function summary(request) {
    const { method, path, phase, status, code, duration, outcome } = request;
    return { method, path, phase, status, code, duration, outcome };
  }
  function requestDetails(request) {
    return { ...summary(request), url: request.url,
      requestHeaders: request.requestHeaders, requestBody: request.requestBody,
      responseHeaders: request.responseHeaders, responseFormat: request.responseFormat,
      responseBody: request.responseBody, responseRaw: request.responseRaw, error: request.error };
  }
  function renderRequests() {
    const list = get("requests");
    list.replaceChildren();
    get("empty").hidden = state.requests.length > 0;
    for (const request of state.requests) {
      const row = document.createElement("li");
      row.className = request.outcome === "failed" ? "debug-request-failed" : "";
      const expandable = document.createElement("details");
      expandable.className = "debug-request-details";
      expandable.open = request.expanded === true;
      expandable.addEventListener("toggle", () => { request.expanded = expandable.open; });
      const heading = document.createElement("summary");
      const name = document.createElement("code");
      name.textContent = request.method + " " + request.path;
      const detail = document.createElement("span");
      const status = request.status == null ? "未取得 HTTP 响应" : "HTTP " + request.status;
      detail.textContent = request.phase === "start" ? "请求中…（点击展开）" :
        status + " · " + request.duration + " ms" + (request.code == null ? "" : " · code=" + request.code) +
        (request.outcome === "ok" ? " · 成功" : " · 失败") + " · 点击展开";
      heading.append(name, detail);
      expandable.appendChild(heading);
      const body = document.createElement("div");
      body.className = "debug-request-content";
      const address = document.createElement("code");
      address.textContent = request.url ? new URL(request.url, window.location.href).href : request.path;
      body.appendChild(address);
      const hint = document.createElement("p");
      hint.className = "debug-hint";
      hint.textContent = "HTTP Header 只列代码显式设置的头；Response Header 仅包含浏览器允许 JS 读取的部分。详情可能含会话凭据。";
      body.appendChild(hint);
      function section(title, value, fallback) {
        const label = document.createElement("h4");
        label.textContent = title;
        const content = document.createElement("pre");
        content.textContent = value === undefined ? fallback : typeof value === "string" ? value : JSON.stringify(value, null, 2);
        body.append(label, content);
      }
      section("HTTP Header（代码设置）", request.requestHeaders, "等待发送");
      section("Request（加密前，含 http_headers）", request.requestBody, "等待发送");
      section("Response Header（JS 可读取）", request.responseHeaders, "尚未取得可读响应");
      section("Response（" + (request.responseFormat || "等待响应") + "）", request.responseBody, "尚未取得可读响应");
      if (request.responseRaw !== undefined && request.responseFormat === "decrypted JSON") {
        section("原始 Response（加密文本）", request.responseRaw, "");
      }
      if (request.error) section("请求错误", request.error, "");
      const copyButton = document.createElement("button");
      copyButton.type = "button";
      copyButton.textContent = "复制此请求详情";
      copyButton.addEventListener("click", () => copy(JSON.stringify(requestDetails(request), null, 2)));
      body.appendChild(copyButton);
      expandable.appendChild(body);
      row.appendChild(expandable);
      list.appendChild(row);
    }
  }
  async function copy(value, field) {
    if (!value) { display("message", "暂无可复制的数据。"); return; }
    try {
      if (!navigator.clipboard?.writeText) throw new Error("Clipboard unavailable");
      await navigator.clipboard.writeText(value);
    } catch {
      const target = field || document.createElement("textarea");
      if (!field) { target.className = "debug-copy-fallback"; target.value = value; panel.appendChild(target); }
      let copied = false;
      try {
        target.focus(); target.select(); target.setSelectionRange(0, value.length);
        copied = document.execCommand("copy") === true;
      } catch {} finally { if (!field) target.remove(); }
      if (!copied) { display("message", "请长按输入框手动复制。"); return; }
    }
    display("message", "已复制。");
  }
  get("copy-user").addEventListener("click", () => copy(state.userID, get("user")));
  get("copy-device").addEventListener("click", () => copy(state.deviceID, get("device")));
  get("copy-summary").addEventListener("click", () => copy(JSON.stringify({
    api: state.config.baseURL, package: state.config.package, version: state.config.version,
    userID: state.userID, deviceID: state.deviceID, cache: state.cache, isReviewPkg: state.policy,
    route: state.route, requests: state.requests.map(summary)
  }, null, 2)));
  get("minimize").addEventListener("click", () => {
    const hidden = !get("body").hidden;
    get("body").hidden = hidden;
    get("minimize").textContent = hidden ? "展开" : "收起";
    get("minimize").setAttribute("aria-expanded", String(!hidden));
  });
  get("refresh").addEventListener("click", () => {
    if (get("refresh").disabled) return;
    let storage;
    try { storage = window.localStorage; } catch {}
    window.CraftkinActivity.forget(storage);
    const url = new URL(window.location.href);
    url.searchParams.set("debug", "1");
    url.searchParams.set("refresh", "1");
    window.location.replace(url.href);
  });
  get("continue").addEventListener("click", () => {
    if (!resume) return;
    const next = resume; resume = null;
    get("continue").disabled = true;
    get("refresh").disabled = true;
    panel.hidden = true;
    next();
  });
  window.CraftkinDebug = Object.freeze({
    enabled: true,
    begin(config) {
      panel.hidden = false;
      state.config = { baseURL: config.baseURL, package: config.package, version: config.version };
      state.requests = []; state.cache = "等待检查"; state.policy = "尚未请求"; state.route = "等待结果";
      identity("");
      display("api", config.baseURL); display("package", config.package + " / " + config.version);
      display("cache", state.cache); display("policy", state.policy); display("route", state.route);
      display("message", ""); get("error").hidden = true;
      get("refresh").disabled = true; get("continue").disabled = true;
      renderRequests();
    },
    context(context) { state.deviceID = context.installationID; get("device").value = state.deviceID; },
    event(event) {
      if (event.kind === "request") {
        const safe = { method: event.method, path: event.path, phase: event.phase, status: event.status ?? null,
          code: event.code ?? null, duration: event.duration ?? 0, outcome: event.outcome || "pending" };
        for (const field of ["url", "requestHeaders", "requestBody", "responseHeaders", "responseBody", "responseRaw", "responseFormat", "error"]) {
          if (Object.prototype.hasOwnProperty.call(event, field)) safe[field] = event[field];
        }
        if (event.phase === "start") state.requests.push(safe);
        else {
          const row = state.requests.findLast(item => item.path === safe.path && item.phase === "start");
          if (row) Object.assign(row, safe); else state.requests.push(safe);
        }
        state.requests = state.requests.slice(-30); renderRequests();
      } else if (event.kind === "identity") identity(event.userID);
      else if (event.kind === "cache") {
        state.cache = event.hit ? "命中：本轮跳过 IP / config / auth / strategy" : "未命中：请求最新策略";
        display("cache", state.cache);
        if (event.hit) { identity(event.userID); state.policy = "未请求，不能代表当前后台值"; display("policy", state.policy);
          if (!event.userID) display("message", "旧缓存未保存 User ID，可清活动缓存并重请求获取。"); }
      } else if (event.kind === "strategy") {
        state.policy = typeof event.isReviewPkg === "boolean" ? String(event.isReviewPkg) : "字段类型异常：" + event.valueType;
        display("policy", state.policy + (event.isReviewPkg === true ? " → 协议" : event.isReviewPkg === false ? " → 活动" : ""));
      } else if (event.kind === "route") {
        state.route = (event.route === "legal" ? "协议" : "活动") + (event.source === "cache" ? "（来自缓存）" : "（来自接口）");
        display("route", state.route);
      }
    },
    wait(result) {
      identity(result.userID);
      get("refresh").disabled = false; get("continue").disabled = false;
      get("continue").textContent = "继续";
      return new Promise(resolve => { resume = resolve; });
    },
    failure() { panel.hidden = false; resume = null; get("error").hidden = false;
      get("refresh").disabled = false; get("continue").disabled = true; }
  });
})();
