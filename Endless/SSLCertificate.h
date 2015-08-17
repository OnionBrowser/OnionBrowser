/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

@property (readonly) BOOL isEV;
@property (strong, readonly) NSString *evOrgName;

- (id)initWithSecTrustRef:(SecTrustRef)secTrustRef;
- (id)initWithData:(NSData *)data;
- (BOOL)isExpired;
- (BOOL)hasWeakSignatureAlgorithm;

@end
