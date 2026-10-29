import Foundation

enum WebStartupStage: Int {
    case setup = 0, configuration, authentication, directory, entry, page
}

struct WebTransportFailure: Error {
    let reason: WebIntegrationError
    var nativeCode: Int? = nil
    var httpStatus: Int? = nil
}

struct WebEndpointSummary: Equatable {
    let webOrigin: String?
    let messagingOrigin: String?
    let eventsOrigin: String?

    init(values: [Any]) {
        func origin(_ index: Int) -> String? {
            guard values.indices.contains(index), let value = values[index] as? String,
                  let parts = URLComponents(string: value), let scheme = parts.scheme?.lowercased(),
                  [IntegrationConstants.Route.secure, IntegrationConstants.Route.plain, IntegrationConstants.Route.socket].contains(scheme),
                  let host = parts.host?.lowercased(), host.utf8.count <= 253,
                  host.unicodeScalars.allSatisfy({ $0.isASCII && (CharacterSet.alphanumerics.contains($0) || $0 == "." || $0 == "-") }) else { return nil }
            return scheme + "://" + host + (parts.port.map { ":" + String($0) } ?? "")
        }
        webOrigin = origin(0)
        messagingOrigin = origin(1)
        eventsOrigin = origin(2)
    }

    var description: String {
        typealias D = IntegrationConstants.Diagnostic
        let missing = IntegrationConstants.Text.missingAddress
        return [(D.webpage, webOrigin), (D.messaging, messagingOrigin), (D.events, eventsOrigin)]
            .map { $0.0 + ": " + ($0.1 ?? missing) }.joined(separator: "\n")
    }
}

struct WebDirectoryFailure: Error {
    let reason: WebIntegrationError
    let endpoints: WebEndpointSummary
}

struct WebStartupFailure: Error, Equatable {
    let stage: WebStartupStage
    let reason: WebIntegrationError
    let nativeCode: Int?
    let httpStatus: Int?
    let endpoints: WebEndpointSummary?

    init(stage: WebStartupStage, error: Error) {
        self.stage = stage
        endpoints = (error as? WebDirectoryFailure)?.endpoints
        if let directory = error as? WebDirectoryFailure {
            reason = directory.reason
            nativeCode = nil; httpStatus = nil
        } else if let transport = error as? WebTransportFailure {
            reason = transport.reason
            nativeCode = transport.nativeCode
            httpStatus = transport.httpStatus
        } else if let reason = error as? WebIntegrationError {
            self.reason = reason
            nativeCode = nil; httpStatus = nil
        } else {
            let native = error as NSError
            nativeCode = native.domain == NSURLErrorDomain ? native.code : nil
            httpStatus = nil
            if native.domain == NSURLErrorDomain {
                reason = native.code == NSURLErrorNotConnectedToInternet ? .offline : .network
            } else { reason = .malformedResponse }
        }
    }

    var reference: String {
        typealias D = IntegrationConstants.Diagnostic
        let prefix = D.prefix + "-" + String(stage.rawValue) + "-"
        if let nativeCode { return prefix + D.native + String(nativeCode) }
        if let httpStatus { return prefix + D.http + String(httpStatus) }
        return prefix + D.reason + String(reasonNumber)
    }

    private var reasonNumber: Int {
        switch reason {
        case .unavailable: return 1
        case .malformedResponse: return 2
        case .invalidConfiguration: return 3
        case .network: return 4
        case .offline: return 5
        case .expired: return 6
        case .addressDenied: return 7
        case .encoding: return 8
        case .unsupported: return 9
        case .invalidMessage: return 10
        case .missingEntryMaterial: return 11
        case .servicesUnavailable: return 12
        case .emptyPage: return 13
        }
    }
}
