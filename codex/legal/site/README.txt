最新状态（2026-11-19，优先于下方历史记录）：
- 当前原生配置入口为 https://craftkin.pages.dev（根地址），不再是 /start。根页目前仍为协议目录；本次只精简文本，未改入口流程。
- 隐私政策 8 节、服务协议 7 节，统一联系邮箱 EchoSkillContact@outlook.com。
- 本次文本针对当前本地功能和线上静态协议；未上线活动不作为已启用服务描述。未来部署活动前，必须按实际接口、数据用途/留存、运营主体和收费情况更新对应说明，不能原样沿用当前文本。
- build_site.py 不再追加未上线活动的隐私段落；保留的活动 JS、start 页面及其交互实现未修改。
- 最新静态部署：https://caccf7a3.craftkin.pages.dev；正式域名：https://craftkin.pages.dev。
- 生成顺序：python3 codex/legal/site/build_site.py，再运行 python3 codex/legal/site/build_static.py；仅部署 static-public/。

下方为历史记录，入口及联系方式以本段和当前源码为准。

Craftkin / EchoSkill 协议与活动启动站

当前状态（第 19 次更新）：App 保持固定 /start 入口，线上发布纯静态协议版本。
第 20 次更新：App 内置离线协议及离线阅读入口已删除，仅加载在线页面；网络失败保留 Retry。Cloudflare 部署内容不变。
当前部署目录：codex/legal/site/static-public/
静态生成脚本：codex/legal/site/build_static.py
静态部署配置：codex/legal/site/static/wrangler.jsonc
App 启动入口：https://craftkin.pages.dev/start（原生照常附加 consent=app），已去掉 debug=1。
第 21 次更新：原生只配置 startupURL，协议/隐私地址和回调主机均由它派生，已移除单独的 websiteURL 常量。
第 22 次更新：原生启动只判断已保存的同意结果：进入过 A 面则直接进入原生，否则只打开固定 /start。关闭活动也回 /start，删除直接跳 /terms 的原生启动分支。
当前 /start 和 /start.html 通过 302 转到 /terms?consent=app，固定入口直接显示静态协议。
静态版本不加载活动、接口请求、调试、加密或活动缓存代码，保留底部固定同意按钮和原生回调。
活动 H5 完整源码仍保留在 public/，build_site.py 和原 wrangler.jsonc 也保留；目前不作为线上部署目录。
用户说明活动正在筹备，要求入口地址保持固定，以后部署网站内容时不用修改原生 URL。活动源码保持完整。
既有同意记录仍生效：已同意的用户直接进入原生首页，跳过 H5；固定入口不代表这些用户会自动看到后续网页内容。

当前构建及部署：
python3 codex/legal/site/build_static.py
在 codex/legal/site/static/ 目录运行：
CLOUDFLARE_ACCOUNT_ID=9a52c7d856566b65c298366118dc1e4e npx wrangler pages deploy ../static-public --project-name craftkin --branch main --commit-dirty=true

以下为保留的活动实现及历次维护记录，涉及活动启动和调试窗口的描述不代表当前线上静态版本。

项目：craftkin（独立 Cloudflare Pages，账户 9a52c7d856566b65c298366118dc1e4e）
入口：https://craftkin.pages.dev/start?consent=app
协议：https://craftkin.pages.dev/terms
隐私：https://craftkin.pages.dev/privacy
最近主站部署：https://89453b13.craftkin.pages.dev
App 品牌继续使用原有 EchoSkill。

启动业务
已明确同意当前版本协议：原生直接进入原有引导/资料库。
未同意：启动 H5 Loading -> privacyAndTerms / legalConsent2 取得 Keychain 安装标识 -> 命中活动缓存直接恢复；未命中则查询 /cdn-cgi/trace，再 config/auth/strategy -> 协议或活动。
协议底部 Agree and continue 是真实 H5 按钮，legalConsent 回调校验后在 UserDefaults 记录同意结果。
H5 接口、AES、活动缓存、Token 链接更新与 XFF 请求头仍在网站脚本，原生只处理 URL、网页交互、Keychain、同意记录和显示。

配置
沿用用户确认的 Craftkin 配置：test-app.dirtan.work、com.huankecontact.test、R3f6s4k/7aP9g2d/m5T1z8b，消息与事件域名同原工程。当前仍为测试服务配置；路由 xttest，生产切换时按 config_h5app_urlpath，并同步 CSP/环境标识。入口与客服 URL 在原始密文后追加 &cv=2。
Keychain 继续使用 EchoSkill.WebIntegration / activity.installation.identifier；新域名不能直接读取旧 Worker 域名的网站存储。

原生网页交互
b 打开独立网页容器 presentPrivacyAndTerms；c 直接交 UIApplication.open；h 关闭页面。活动导航按用户要求不添加来源、域名、协议黑白名单等额外限制；about:blank 留在 WebKit。
支付/第三方网页当前是 large 大屏卡片，不能下拉关闭，拖动条隐藏，导航栏右侧 Close 按钮。活动和启动协议主体仍铺满屏幕。

生成和发布
python3 codex/legal/site/build_site.py
CLOUDFLARE_ACCOUNT_ID=9a52c7d856566b65c298366118dc1e4e npx wrangler pages deploy codex/legal/site/public --project-name craftkin --branch main --commit-dirty=true
原内置协议同步功能现已按用户要求移除，生成脚本只生成网站页面，不再写入 App 资源。当前线上使用 static-public/，此处 public/ 是保留的活动源码。

维护记录
最新清理说明：codex/implementation/07-ios-source-cleanup/IMPLEMENTATION.txt。
按用户要求已删除测试源码、测试 Target、测试脚本和仓库 .log 文件；旧 implementation 目录中的测试结果属于历史记录。当前验证采用 App 编译，实际手机支付及显示效果仍由用户验收。
协议正文沿用原有 Google 文档，保留原经营者、日期、邮箱及尚未填写的在线服务等字段，没有自行编造。

H5 调试窗口（用户后续新增）
https://craftkin.pages.dev/start?consent=app&debug=1
当前原生 startupURL 临时带 debug=1，重新安装后可在实际 Keychain 身份下查看窗口。窗口展示请求状态/耗时、User ID/Device ID、缓存和策略值，复制数据，并可清活动缓存后重新请求。调试时先停在启动页，点击继续再打开目标页面。关闭调试删除 URL 的 debug 参数；不依赖 isReviewPkg 或原生 DEBUG。
已同意协议会跳过 H5；独立浏览器身份不代表 App 身份。窗口支持点击请求展开 HTTP Header、加密前请求体（含 http_headers）、可读取的响应头、完整解密 Response 和原始响应，每条可复制详情。复制摘要仍只有概要；完整详情可能包含身份和会话值，仅在当前页内存展示，不上传或持久化。最初窗口说明见 codex/implementation/08-h5-debug-window/IMPLEMENTATION.txt，内容以当前实现为准。

启动主体现在只显示一个菊花，去掉品牌/加载标题/进入页面提示；原生加载指示也无可见文字。调试信息仍保留在 debug 窗口中，见第 09 次记录。

当前上送接口版本固定 1.0.2（三接口 http_headers.ver 和活动密文 i）；与 iOS 工程营销版本独立。旧活动缓存自动迁移版本参数；核对策略时手动清活动缓存重请求。详见第 10 次记录。

Mock 已取消（第 15 次更新）
用户确认接口已经可以调试，已撤回独立 Mock 入口、原生临时配置和本地 Mock 源码。
App 恢复 https://craftkin.pages.dev/start?debug=1，实际打开时照常附加 consent=app。
保留请求 Header / Response 展开详情，继续使用真实接口和原有同意记录，不改设备标识或活动缓存。
第 12 至 14 次记录属于已撤回的历史方案，以第 15 次记录为准。

协议底部固定按钮（第 16 次更新）
App 协议场景的 Agree and continue 固定在屏幕底部，正文可滚动，并按底栏实际高度预留空间；安全区和失败提示自适应。
仍用既有 legalConsent 回调保存同意结果。内置离线协议同步相同布局，无新的原生业务逻辑。

原生协议 WebView 已移除网页域名/路径白名单；任意普通网页可以在当前容器打开。JS 原生消息仍单独校验来源和消息格式，见第 17 次记录。
