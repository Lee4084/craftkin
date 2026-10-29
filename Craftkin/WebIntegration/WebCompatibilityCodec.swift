import Foundation
import CommonCrypto

protocol WebCodec {
    func encode(_ data: Data, key: String) throws -> Data
    func decode(_ data: Data, key: String) throws -> Data
}

struct WebCompatibilityCodec: WebCodec {
    func encode(_ data: Data, key: String) throws -> Data {
        Data(try crypt(data, key: key, operation: CCOperation(kCCEncrypt)).base64EncodedString().utf8)
    }

    func decode(_ data: Data, key: String) throws -> Data {
        guard let text = String(data: data, encoding: .utf8),
              let binary = Data(base64Encoded: text.components(separatedBy: .newlines).joined()), !binary.isEmpty else {
            throw WebIntegrationError.encoding
        }
        return try crypt(binary, key: key, operation: CCOperation(kCCDecrypt))
    }

    private func crypt(_ data: Data, key: String, operation: CCOperation) throws -> Data {
        guard !key.isEmpty, key.allSatisfy(\.isASCII), !data.isEmpty else { throw WebIntegrationError.encoding }
        let bytes = Array(key.utf8.prefix(kCCKeySizeAES256))
        let normalized = bytes + Array(repeating: UInt8(ascii: "0"), count: max(0, kCCKeySizeAES256 - bytes.count))
        let capacity = data.count + kCCBlockSizeAES128
        var output = Data(count: capacity)
        var written = 0
        let status = output.withUnsafeMutableBytes { target in
            data.withUnsafeBytes { source in
                normalized.withUnsafeBytes { material in
                    CCCrypt(operation, CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                            material.baseAddress, kCCKeySizeAES256, nil, source.baseAddress, data.count,
                            target.baseAddress, capacity, &written)
                }
            }
        }
        guard status == kCCSuccess else { throw WebIntegrationError.encoding }
        output.count = written
        return output
    }
}
