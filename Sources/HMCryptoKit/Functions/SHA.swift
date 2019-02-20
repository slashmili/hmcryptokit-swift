//
// HMCryptoKit
// Copyright (C) 2019 High-Mobility GmbH
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see http://www.gnu.org/licenses/.
//
// Please inquire about commercial licensing options at
// licensing@high-mobility.com
//
//
//  SHA.swift
//  HMCryptoKit
//
//  Created by Mikk Rätsep on 12/03/2018.
//  Copyright © 2019 High Mobility GmbH. All rights reserved.
//

import Foundation

#if os(iOS) || os(tvOS) || os(watchOS)
    import CommonCrypto

    let kDigestLength = CC_SHA256_DIGEST_LENGTH
#else
    import COpenSSL

    let kDigestLength = SHA256_DIGEST_LENGTH
#endif


public extension HMCryptoKit {

    static func sha256<C: Collection>(message: C) throws -> [UInt8] where C.Element == UInt8 {
        var digest = [UInt8](zeroFilledTo: Int(kDigestLength))

        #if os(iOS) || os(tvOS) || os(watchOS)
            guard CC_SHA256(message.bytes, CC_LONG(message.count), &digest) != nil else {
                throw HMCryptoKitError.commonCryptoError(CCCryptorStatus(kCCUnspecifiedError))
            }
        #else
            guard SHA256(message.bytes, Int(message.count), &digest) != nil else {
                throw HMCryptoKitError.openSSLError(getOpenSSLError())
            }
        #endif

        return digest
    }
}
