import Foundation

enum IntegrationConstants {
    static var environmentValues: [String: Any] {
        #if DEBUG
        return testEnvironmentValues
        #else
        return [:]
        #endif
    }
    static var testEnvironmentValues: [String: Any] {
        [Configuration.environment: Configuration.test,
         Configuration.api: Host.api,
         Configuration.origins: [Host.web],
         Configuration.paths: [Route.base],
         Configuration.trustedRoot: Host.root,
         Configuration.serviceOrigins: [Host.messaging, Host.messagingHTTP, Host.events],
         Configuration.messaging: Host.messaging,
         Configuration.events: Host.events,
         Configuration.externalOrigins: [Legal.origin],
         Configuration.terms: Legal.terms,
         Configuration.privacy: Legal.privacy,
         Configuration.partFields: ServerField.fragments,
         Configuration.segmentOverride: Route.testSegment,
         Configuration.confirmed: true]
    }
    enum Host {
        static let root = "dirtan.work"
        static let api = "https://test-app.dirtan.work"
        static let web = "https://test-h5.tipobox.cc"
        static let messaging = "wss://test-im.dirtan.work"
        static let messagingHTTP = "https://test-im.dirtan.work"
        static let events = "https://test-log.dirtan.work"
    }
    enum Legal {
        static let origin = "https://docs.google.com"
        static let terms = "https://docs.google.com/document/d/1_n_EIH15GouK_fi39pvzv2okSYAd1Z8SnJZSB32UjDs/edit?tab=t.0"
        static let privacy = "https://docs.google.com/document/d/1m9yUn_udhrEuamoTg9p8Obmc6sjTb2aIEx3u5Fk-yBI/edit?tab=t.0"
    }
    enum ServerField {
        // Protocol field aliases from the supplied environment; not AES material.
        static let fragments = ["R3f6s4k", "7aP9g2d", "m5T1z8b"]
    }
    enum Catalog {
        static let productIDs = (978793231...978793240).map(String.init)
    }
    enum Configuration {
        static let environment = "environment"
        static let api = "apiOrigin"
        static let origins = "webOrigins"
        static let trustedRoot = "trustedWebRoot"
        static let paths = "webPathPrefixes"
        static let serviceOrigins = "serviceOrigins"
        static let messaging = "messagingURL"
        static let events = "eventsURL"
        static let externalOrigins = "externalOrigins"
        static let terms = "termsURL"
        static let privacy = "privacyURL"
        static let partFields = "configurationFields"
        static let entryKey = "entryMaterial"
        static let confirmed = "contractConfirmed"
        static let segmentOverride = "segmentOverride"
        static let test = "test"
        static let production = "production"
        static let debugMaterial = "ECHO_WEB_ENTRY_MATERIAL"
        static let testingArgument = "-uiTesting"
        static let disabledArgument = "-disableOnlineServices"
        static let nativeTestingArgument = "-nativeOnlineServices"
    }
    enum Endpoint {
        static let configuration = "/config/getAppConfigPostV2"
        static let session = "/security/oauth"
        static let services = "/config/getStrategyPostV2"
        static let startup = [configuration, session, services]
    }
    enum Field {
        static let code = "code", data = "data", headers = "http_headers"
        static let version = "ver", token = "token", authentication = "oauthType", user = "userId"
        static let userInfo = "userInfo", nativePage = "isReviewPkg"
        static let items = "items", name = "name", extensionData = "app_ext_data"
        static let segment = "config_h5app_urlpath", domains = "dr", contact = "userServiceAccountId"
    }
    enum Header {
        static let method = "POST", contentType = "Content-Type", contentValue = "application/json"
        static let installation = "device-id", language = "lang", deviceLanguage = "device_lang"
        static let systemLanguage = "sys_lan", model = "model", zone = "time_zone", region = "device_country"
        static let system = "platform_ver", locale = "system_language", user = "user_id", bundle = "pkg"
        static let authorization = "Authorization", bearer = "Bearer ", anchor = "is_anchor"
        static let platform = "platform", platformValue = "iOS", revision = "sec_ver", zero = "0"
        static let defaultLanguage = "en"
    }
    enum ShortField {
        static let installation = "a", credential = "b", bundle = "c", api = "d", messaging = "e"
        static let events = "f", terms = "g", privacy = "h", version = "i", name = "j"
        static let partOne = "k", partTwo = "l", partThree = "m"
    }
    enum Route {
        static let secure = "https", socket = "wss", root = "/", base = "/h5_web/", fragment = "#/"
        static let plain = "http", blank = "about:blank"
        static let blockedSchemes: Set<String> = ["file", "javascript", "data", "about", "blob", "go",
                                                   "app-settings", "prefs", "itms-services", "applewebdata"]
        static let contact = "#/pages/chat/chat?userId="
        static let testSegment = "drtest"
    }
    enum Bridge {
        static let scheme = "go", argument = "t_pams"
        static let endSession = "a", internalPage = "b", externalPage = "c", event = "d", transaction = "e"
        static let settings = "f", awake = "g", close = "h", history = "i", contact = "vs"
        static let yes = "true", no = "false"
        static let actions: Set<String> = [endSession, internalPage, externalPage, event, transaction,
                                            settings, awake, close, history, contact]
    }
    enum Storage {
        static let service = "EchoSkill.WebIntegration"
        static let installation = "installation.identifier"
        static let entryMaterial = "entry.material"
        static let rootDestination = "session.root.destination"
    }
    enum BundleKey {
        static let version = "CFBundleShortVersionString", displayName = "CFBundleDisplayName", name = "CFBundleName"
    }
    enum Limit {
        static let request: TimeInterval = 15
        static let startup: UInt64 = 45_000_000_000
        static let navigation: UInt64 = 30_000_000_000
        static let contentProbe: UInt64 = 500_000_000
        static let message = 16_384
        static let response = 1_048_576
    }
    enum Script {
        // Return a boolean only; webpage text and form values stay inside WebKit.
        static let renderedContent = """
        (() => {
          const body = document.body;
          if (!body) return false;
          if ((body.innerText || '').trim().length > 0) return true;
          return Array.from(body.querySelectorAll('img,svg,canvas,video,iframe,input,button,textarea,select')).some(element => {
            const bounds = element.getBoundingClientRect();
            const style = getComputedStyle(element);
            return bounds.width > 0 && bounds.height > 0 && bounds.bottom > 0 && bounds.right > 0
              && bounds.top < innerHeight && bounds.left < innerWidth
              && style.display !== 'none' && style.visibility !== 'hidden' && style.opacity !== '0';
          });
        })()
        """
    }
    enum Diagnostic {
        static let prefix = "H5"
        static let native = "U"
        static let http = "H"
        static let reason = "R"
        static let identifier = "online-services-diagnostic"
        static let webpage = "H5"
        static let messaging = "IM"
        static let events = "Log"
        static let action = "Action", context = "Context", unknownAction = "unknown"
        static let capability = "capability", bridge = "bridge"
    }
    enum Trace {
        static let requestID = "request_id", stage = "stage", event = "event", origin = "origin"
        static let path = "path", error = "error", status = "http_status"
        static let start = "start", response = "response", success = "success", failure = "failure"
        static let cancelled = "cancelled", document = "document_loaded", content = "content_visible"
        static let encodingFailure = "diagnostic_encoding_failed"
    }
    enum Symbol {
        static let back = "chevron.backward"
    }
    enum Text {
        static let title = String(localized: "Online services")
        static let legal = String(localized: "Legal")
        static let terms = String(localized: "User Agreement")
        static let privacy = String(localized: "Privacy Policy")
        static let termsID = "legal-terms", privacyID = "legal-privacy"
        static let subtitle = String(localized: "Open connected services")
        static let unavailable = String(localized: "Online services are not available yet. Your saved lessons are still available.")
        static let missingMaterial = String(localized: "The connection settings are incomplete. Please contact support.")
        static let missingServices = String(localized: "The service did not provide a webpage address. Please contact support.")
        static let missingAddress = String(localized: "Not provided or invalid")
        static let loading = String(localized: "Connecting…")
        static let failed = String(localized: "We couldn’t open this page. Please try again.")
        static let emptyPage = String(localized: "The webpage loaded, but its content did not appear. Please try again.")
        static let offline = String(localized: "This app cannot access the internet. Check your connection and allow Wi-Fi or cellular data in Settings, then try again.")
        static let openSettings = String(localized: "Open Settings")
        static let denied = String(localized: "This link cannot be opened here.")
        static let unsupported = String(localized: "This action is not available.")
        static let retry = String(localized: "Try Again"), close = String(localized: "Close"), back = String(localized: "Back"), okay = String(localized: "OK")
        static let issue = String(localized: "Unable to continue")
        static let entryID = "online-services-entry", closeID = "online-services-close", unavailableID = "online-services-unavailable"
    }
}
