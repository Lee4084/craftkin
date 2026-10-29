import Foundation

enum WebRequestEvent {
    case start, response, success, failure, cancelled, document, content

    var label: String {
        typealias T = IntegrationConstants.Trace
        switch self {
        case .start: return T.start
        case .response: return T.response
        case .success: return T.success
        case .failure: return T.failure
        case .cancelled: return T.cancelled
        case .document: return T.document
        case .content: return T.content
        }
    }
}

struct WebRequestTrace {
    let stage: WebStartupStage
    let url: URL?
    var installationID: String? = nil
    var userID: String? = nil
    var id = UUID()

    static let prefix = "[" + IntegrationConstants.Diagnostic.prefix + "] "

    func line(_ event: WebRequestEvent, userID returnedUserID: String? = nil,
              httpStatus: Int? = nil, error: Error? = nil) -> String {
        typealias T = IntegrationConstants.Trace
        var fields: [String: Any] = [T.requestID: id.uuidString, T.stage: stage.rawValue, T.event: event.label]
        if let installationID, !installationID.isEmpty { fields[IntegrationConstants.Header.installation] = installationID }
        if let user = returnedUserID ?? userID, !user.isEmpty { fields[IntegrationConstants.Header.user] = user }
        if let url {
            fields[T.origin] = WebEndpointSummary(values: [url.absoluteString]).webOrigin
            if IntegrationConstants.Endpoint.startup.contains(url.path) { fields[T.path] = url.path }
        }
        if let httpStatus { fields[T.status] = httpStatus }
        if let error { fields[T.error] = WebStartupFailure(stage: stage, error: error).reference }
        guard let data = try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return Self.prefix + T.encodingFailure
        }
        return Self.prefix + json
    }

    func emit(_ event: WebRequestEvent, userID: String? = nil, httpStatus: Int? = nil,
              error: Error? = nil, output: (String) -> Void = WebRequestTrace.debugOutput) {
        #if DEBUG
        output(line(event, userID: userID, httpStatus: httpStatus, error: error))
        #endif
    }

    static func debugOutput(_ line: String) {
        #if DEBUG
        print(line)
        #endif
    }
}
