//
//  SecureEnclave.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 12.03.20.
//  Copyright © 2020 - 2021, Tigas Ventures, LLC (Mike Tigas).
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

/**
Encapsulates all cryptography where the secure enclave is used.

References:
https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/storing_keys_in_the_secure_enclave
https://medium.com/@alx.gridnev/ios-keychain-using-secure-enclave-stored-keys-8f7c81227f4
*/
class SecureEnclave: NSObject {

	/**
	Tag of the single private key we're using.
	*/
	static let tag = "Onion Browser".data(using: .utf8)!

	/**
	Create a private/public key pair using our one tag inside the secure enclave.
	Don't call this, if there's already one existing!

	The key can be used by the user when entering the device passcode or using any enrolled biometry.

	The key will be stored on this device only.

	- returns: The reference to the created private key or `nil` if something goes horribly wrong.
	*/
	@discardableResult
	class func createKey() -> SecKey? {
		let flags: SecAccessControlCreateFlags = [.privateKeyUsage, .userPresence]

		guard let access = SecAccessControlCreateWithFlags(
				kCFAllocatorDefault, kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
				flags, nil)
			else {
				return nil
		}

		// Only elliptic curve 256 bit keys can be created inside the secure enclave.
		// So don't mess with these parameters!
		let parameters: [CFString: Any] = [
			kSecAttrKeyType: kSecAttrKeyTypeEC,
			kSecAttrKeySizeInBits: 256,
			kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
			kSecPrivateKeyAttrs: [
				kSecAttrIsPermanent: true,
				kSecAttrApplicationTag: tag,
				kSecAttrAccessControl: access]]

		return SecKeyCreateRandomKey(parameters as CFDictionary, nil)
	}

	/**
	Load the private key from the secure enclave.

	- returns: the reference to the private key or `nil` if there is no key to be found under our `tag`.
	*/
	class func loadKey() -> SecKey? {
		var item: CFTypeRef?
		let query: [CFString: Any] = [
			kSecClass: kSecClassKey,
			kSecAttrApplicationTag: tag,
			kSecAttrKeyType: kSecAttrKeyTypeEC,
			kSecReturnRef: true]

		if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess {
			return (item as! SecKey)
		}

		return nil
	}

	/**
	Removes the created key from the secure enclave.

	- returns: `true` on success, `false` on failure.
	*/
	class func removeKey() -> Bool {
		let query: [CFString: Any] = [
			kSecClass: kSecClassKey,
			kSecAttrApplicationTag: tag,
			kSecAttrKeyType: kSecAttrKeyTypeEC]

		return SecItemDelete(query as CFDictionary) == errSecSuccess
	}

	/**
	- parameter key: A private key.
	- returns: the public key of the given private key or `nil` if something goes horribly wrong.
	*/
	class func getPublicKey(_ key: SecKey) -> SecKey? {
		return SecKeyCopyPublicKey(key)
	}

	/**
	Sign a given piece of data with the given private key.

	- parameter data: Data to sign.
	- parameter key: Private key to use for the signature.
	- returns: the signature, or `nil` if `data` is `nil` or if something goes horribly wrong.
	*/
	class func sign(_ data: Data?, with key: SecKey) -> Data? {
		guard let data = data else {
			return nil
		}

		guard SecKeyIsAlgorithmSupported(key, .sign, .ecdsaSignatureMessageX962SHA256) else {
			return nil
		}

		return SecKeyCreateSignature(key, .ecdsaSignatureMessageX962SHA256,
									 data as CFData, nil) as Data?
	}

	/**
	Verifies a signatture on a given piece of data.

	- parameter data: The data, which was signed.
	- parameter signature: The signature which was produced by `#sign`.
	- parameter publicKey: The public key of the private key with which this signature was created.
	- returns: true if signature is valid, false if invalid or if `data`, `signature` or `publicKey` was nil.
	*/
	class func verify(_ data: Data?, signature: Data?, with publicKey: SecKey?) -> Bool {
		guard let data = data, let signature = signature, let publicKey = publicKey else {
			return false
		}

		return SecKeyVerifySignature(publicKey, .ecdsaSignatureMessageX962SHA256,
							  data as CFData, signature as CFData, nil)
	}

	/**
	Creates a nonce from a UUID.

	- returns: the nonce or `nil` if UTF-8 encoding of the nonce fails.
	*/
	class func getNonce() -> Data? {
		return UUID().uuidString.data(using: .utf8)
	}
}
