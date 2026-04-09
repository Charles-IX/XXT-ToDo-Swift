import Foundation
import CryptoSwift

public enum XXTEncryption {
    private static let key: Array<UInt8> = Array("u2oh6Vu^HWe4_AES".utf8)
    private static let iv: Array<UInt8> = Array("u2oh6Vu^HWe4_AES".utf8)

    public static func encrypt(_ text: String) -> String? {
        do {
            let aes = try AES(key: key, blockMode: CBC(iv: iv), padding: .pkcs7)
            let encrypted = try aes.encrypt(Array(text.utf8))
            return Data(encrypted).base64EncodedString()
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }
}
