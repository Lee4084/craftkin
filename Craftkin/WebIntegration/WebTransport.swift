import Foundation

@MainActor
protocol WebTransport { func send(_ request: URLRequest) async throws -> Data }

final class WebRedirectGuard: NSObject, URLSessionTaskDelegate {
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                               newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

@MainActor
final class WebURLTransport: WebTransport {
    static func failure(for error: Error) -> WebIntegrationError {
        let underlying = error as NSError
        if underlying.domain == NSURLErrorDomain, underlying.code == NSURLErrorNotConnectedToInternet {
            return .offline
        }
        return .network
    }

    private let session: URLSession
    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = IntegrationConstants.Limit.request
        config.timeoutIntervalForResource = IntegrationConstants.Limit.request
        config.httpCookieStorage = nil
        config.urlCache = nil
        session = URLSession(configuration: config, delegate: WebRedirectGuard(), delegateQueue: nil)
    }
    func send(_ request: URLRequest) async throws -> Data {
        do {
            let (stream, response) = try await session.bytes(for: request)
            guard let response = response as? HTTPURLResponse else { throw WebIntegrationError.network }
            guard (200..<300).contains(response.statusCode) else {
                let reason: WebIntegrationError = response.statusCode == 401 || response.statusCode == 403 ? .expired : .network
                throw WebTransportFailure(reason: reason, httpStatus: response.statusCode)
            }
            guard response.expectedContentLength <= IntegrationConstants.Limit.response else { throw WebIntegrationError.malformedResponse }
            var data = Data()
            for try await byte in stream {
                try Task.checkCancellation()
                guard data.count < IntegrationConstants.Limit.response else { throw WebIntegrationError.malformedResponse }
                data.append(byte)
            }
            return data
        } catch is CancellationError { throw CancellationError() }
        catch let error as WebTransportFailure { throw error }
        catch let error as WebIntegrationError { throw error }
        catch {
            if Task.isCancelled { throw CancellationError() }
            let native = error as NSError
            throw WebTransportFailure(reason: Self.failure(for: error), nativeCode: native.domain == NSURLErrorDomain ? native.code : nil)
        }
    }
    deinit { session.invalidateAndCancel() }
}

enum WebResponse {
    static func object(_ data: Data) throws -> [String: Any] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = root[IntegrationConstants.Field.code] as? NSNumber,
              CFGetTypeID(code) != CFBooleanGetTypeID(), code.doubleValue == 0,
              let result = root[IntegrationConstants.Field.data] as? [String: Any] else {
            throw WebIntegrationError.malformedResponse
        }
        return result
    }
}
