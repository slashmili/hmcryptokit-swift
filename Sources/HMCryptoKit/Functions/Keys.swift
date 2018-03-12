//
//  Keys.swift
//  HMCryptoKit
//
//  Created by Mikk Rätsep on 06/03/2018.
//

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
    import Security
#else
    import COpenSSL
#endif


public extension HMCryptoKit {

    #if os(iOS) || os(tvOS) || os(watchOS)
    static func keys() throws -> (privateKey: SecKey, publicKey: SecKey) {
        let params: NSDictionary = [kSecAttrKeyType : kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits : 256]
        var publicKey: SecKey?
        var privateKey: SecKey?

        let status = SecKeyGeneratePair(params, &publicKey, &privateKey)

        switch status {
        case errSecSuccess:
            guard let publicKey = publicKey,
                let privateKey = privateKey else {
                    throw HMCryptoKitError.internalSecretError
            }

            return (privateKey: privateKey, publicKey: publicKey)

        default:
            throw HMCryptoKitError.internalSecretError
        }
    }
    #else
    static func keys() throws -> (privateKey: [UInt8], publicKey: [UInt8]) {
        // Create the key
        guard let key = EC_KEY_new_by_curve_name(NID_X9_62_prime256v1),
            EC_KEY_generate_key(key) == 1,
            EC_KEY_check_key(key) == 1,
            let privateBN = EC_KEY_get0_private_key(key) else {
                throw HMCryptoKitError.internalSecretError
        }

        let privateOffset = 32 - Int(ceil(Float(BN_num_bits(privateBN)) / 8.0))
        var privateKey = [UInt8](zeroFilledTo: 32)

        guard BN_bn2bin(privateBN, &privateKey + privateOffset) == 32 else {
            throw HMCryptoKitError.internalSecretError
        }

        return try keys(privateKey: privateKey)
    }
    #endif


    #if os(iOS) || os(tvOS) || os(watchOS)
    static func keys(privateKey: SecKey) throws -> (privateKey: SecKey, publicKey: SecKey) {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw HMCryptoKitError.internalSecretError
        }

        return (privateKey: privateKey, publicKey: publicKey)
    }
    #else
    static func keys<C: Collection>(privateKey: C) throws -> (privateKey: [UInt8], publicKey: [UInt8]) where C.Element == UInt8 {
        // Handle public key values extraction
        guard let publicBN = BN_new(),
            let bnCtx = BN_CTX_new() else {
                throw HMCryptoKitError.internalSecretError
        }

        let values = try extractGroupAndPoint(privateKey: privateKey)
        var publicKeyZXY = [UInt8](zeroFilledTo: 65)

        guard EC_POINT_point2bn(values.group, values.point, POINT_CONVERSION_UNCOMPRESSED, publicBN, bnCtx) != nil,
            BN_bn2bin(publicBN, &publicKeyZXY) == 65 else {
                throw HMCryptoKitError.internalSecretError
        }

        // POINT_CONVERSION_UNCOMPRESSED produces Z||X||Y, where Z == 0x04
        return (privateKey: privateKey.bytes, publicKey: publicKeyZXY.suffix(from: 1).bytes)
    }
    #endif


    #if os(iOS) || os(tvOS) || os(watchOS)
    static func sharedKey(privateKey: SecKey, publicKey: SecKey) throws -> [UInt8] {
        let params: NSDictionary = [SecKeyKeyExchangeParameter.requestedSize : 32]
        var error: Unmanaged<CFError>?

        guard let sharedKey = SecKeyCopyKeyExchangeResult(privateKey, .ecdhKeyExchangeStandardX963SHA256, publicKey, params, &error) else {
            throw HMCryptoKitError.internalSecretError // throw the wrapped error: HMCryptoKitError.secKeyError(error!.takeRetainedValue())
        }

        return (sharedKey as Data).bytes
    }
    #else
    static func sharedKey<C: Collection>(privateKey: C, publicKey: C) throws -> [UInt8] where C.Element == UInt8 {
        let publicKeyY = publicKey.bytes.suffix(from: 32).bytes

        // Extract some vectors
        guard let key = EC_KEY_new_by_curve_name(NID_X9_62_prime256v1),
            let privateBN = BN_bin2bn(privateKey.bytes, 32, nil),
            let publicXBN = BN_bin2bn(publicKey.bytes, 32, nil),
            let publicYBN = BN_bin2bn(publicKeyY, 32, nil) else {
                throw HMCryptoKitError.internalSecretError
        }

        guard EC_KEY_set_private_key(key, privateBN) == 1 else {
            throw HMCryptoKitError.internalSecretError
        }

        guard let group = EC_KEY_get0_group(key),
            let point = EC_POINT_new(group),
            let bnCtx = BN_CTX_new() else {
                throw HMCryptoKitError.internalSecretError
        }

        var sharedKey = [UInt8](zeroFilledTo: 32)

        guard EC_POINT_set_affine_coordinates_GFp(group, point, publicXBN, publicYBN, bnCtx) == 1,
            ECDH_compute_key(&sharedKey, 32, point, key, nil) != -1 else {
                throw HMCryptoKitError.internalSecretError
        }

        return sharedKey
    }
    #endif
}

#if os(iOS) || os(tvOS) || os(watchOS)
#else
private extension HMCryptoKit {

    static func extractGroupAndPoint<C: Collection>(privateKey: C) throws -> (group: OpaquePointer, point: OpaquePointer) where C.Element == UInt8 {
        guard let group = EC_GROUP_new_by_curve_name(NID_X9_62_prime256v1),
            let privateBN = BN_bin2bn(privateKey.bytes, 32, nil),
            let key = EC_KEY_new_by_curve_name(NID_X9_62_prime256v1),
            let point = EC_POINT_new(group) else {
                throw HMCryptoKitError.internalSecretError
        }

        guard EC_KEY_set_private_key(key, privateBN) == 1,
            EC_KEY_generate_key(key) == 1,
            EC_KEY_check_key(key) == 1,
            EC_POINT_mul(group, point, privateBN, nil, nil, nil) == 1 else {
                throw HMCryptoKitError.internalSecretError
        }

        return (group: group, point: point)
    }
}
#endif
