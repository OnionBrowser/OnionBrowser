/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import <Foundation/Foundation.h>

@interface SSLCertificate : NSObject

/* Relative Distinguished Name (RDN) table */
#define X509_KEY_CN	@"Common Name (CN)"
#define X509_KEY_O	@"Organization (O)"
#define X509_KEY_OU	@"Organizational Unit Number (OU)"
#define X509_KEY_L	@"Locality (L)"
#define X509_KEY_ST	@"State/Province (ST)"
#define X509_KEY_C	@"Country (C)"
#define X509_KEY_SN	@"Serial Number (SN)"

#define X509_KEY_STREET	@"Street Address"
#define X509_KEY_ZIP	@"Postal Code"
#define X509_KEY_SERIAL	@"Serial Number"
#define X509_KEY_BUSCAT	@"Business Category"

@property (strong, readonly) NSDictionary *oids;

@property (strong, readonly) NSNumber *version;
@property (strong, readonly) NSString *serialNumber;
@property (strong, readonly) NSString *signatureAlgorithm;
@property (strong, readonly) NSDictionary *issuer;
@property (strong, readonly) NSDate *validityNotBefore;
@property (strong, readonly) NSDate *validityNotAfter;
@property (strong, readonly) NSDictionary *subject;

@property SSLProtocol negotiatedProtocol;
@property SSLCipherSuite negotiatedCipher;

@property (readonly) BOOL isEV;
@property (strong, readonly) NSString *evOrgName;

- (id)initWithSecTrustRef:(SecTrustRef)secTrustRef;
- (id)initWithData:(NSData *)data;
- (BOOL)isExpired;
- (BOOL)hasWeakSignatureAlgorithm;
- (NSString *)negotiatedProtocolString;
- (NSString *)negotiatedCipherString;

@end
