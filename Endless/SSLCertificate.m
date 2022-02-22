/*
 * Endless
 * Copyright (c) 2015 joshua stein <jcs@jcs.org>
 *
 * See LICENSE file for redistribution terms.
 */

#import "SSLCertificate.h"

#import <DTFoundation/NSData+DTCrypto.h>
#import <DTFoundation/DTASN1Serialization.h>


@implementation SSLCertificate

static NSMutableDictionary <NSData *, NSMutableDictionary *> *certCache = nil;

#define CERT_CACHE_SIZE 25
#define CERT_CACHE_KEY_CERT @"key"
#define CERT_CACHE_KEY_TIME @"time"

- (id)init {
	if (!(self = [super init]))
		return nil;
	
	_isEV = false;
	
	if (!certCache)
		certCache = [[NSMutableDictionary alloc] initWithCapacity:CERT_CACHE_SIZE];
	
	return self;
}

- (id)initWithSecTrustRef:(SecTrustRef)secTrustRef
{
	SecCertificateRef cert = SecTrustGetCertificateAtIndex(secTrustRef, 0);
	NSData *data = (__bridge_transfer NSData *)SecCertificateCopyData(cert);
	
	if (!(self = [self initWithData:data]))
		return nil;
	
	/*
	 * Detecting EV means checking for a whole bunch of OIDs, since each vendor uses a different one.
	 * iOS already knows this and is updated with new ones, so just let it determine EV for us.
	 */
	NSDictionary *trust = (__bridge_transfer NSDictionary *)SecTrustCopyResult(secTrustRef);
	id ev = [trust objectForKey:(__bridge NSString *)kSecTrustExtendedValidation];
	if (ev != nil && (__bridge CFBooleanRef)ev == kCFBooleanTrue) {
		_isEV = true;
		_evOrgName = (NSString *)[trust objectForKey:(__bridge NSString *)kSecTrustOrganizationName];
	}
	
	return self;
}

- (id)initWithData:(NSData *)data
{
	/* x509 cert structure:

		Certificate
			Data
				Version
				Serial Number
			Signature Algorithm ID
				Issuer
				Validity
					Not Before
					Not After
				Subject
				Subject Public Key Info
					Public Key Algorithm
					Subject Public Key
				Issuer Unique Identifier (optional)
				Subject Unique Identifier (optional)
				Extensions (optional)
					...
			Certificate Signature Algorithm
			Certificate Signature

	*/
	
	if (!(self = [self init]))
		return nil;
	
	NSData *certHash = [data dataWithSHA1Hash];
	
	NSMutableDictionary *ocdef = [certCache objectForKey:certHash];
	if (ocdef) {
		SSLCertificate *oc = [ocdef objectForKey:CERT_CACHE_KEY_CERT];
#ifdef TRACE
		NSLog(@"[SSLCertificate] certificate for %@ cached", [[oc subject] objectForKey:X509_KEY_CN]);
#endif
		[ocdef setValue:[NSDate date] forKey:CERT_CACHE_KEY_TIME];
		return oc;
	}

	NSArray *oidtree;
	NSObject *t = [DTASN1Serialization objectWithData:data];
	if (t == nil || ![t isKindOfClass:[NSArray class]]) {
		NSLog(@"[SSLCertificate] OID tree fetching failed, returned %@", t);
		return nil;
	}
	else
		oidtree = (NSArray *)t;
	
	NSArray *cert = [self safeFetchFromArray:oidtree atIndex:0 withType:[NSArray class]];
	if (cert == nil)
		return nil;
	
	NSArray *cData = [self safeFetchFromArray:cert atIndex:0 withType:[NSArray class]];
	if (cData == nil) {
		NSDictionary *cDic = [self safeFetchFromArray:cert atIndex:0 withType:[NSDictionary class]];
		if (cDic == nil) {
			return nil;
		}

		cData = [self safeFetchFromArray:cDic[cDic.allKeys.firstObject] atIndex:0 withType:[NSArray class]];

		if (cData == nil) {
			return nil;
		}
	}

	/* X.509 version (0-based - https://tools.ietf.org/html/rfc2459#section-4.1) */
	NSNumber *tver = [self safeFetchFromArray:cData atIndex:0 withType:[NSNumber class]];
	if (tver == nil)
		return nil;
	if ([tver intValue] == 0x0)
		_version = @1;
	else if ([tver intValue] == 0x1)
		_version = @2;
	else if ([tver intValue] == 0x2)
		_version = @3;
	
	/* certificate serial number (string of hex bytes) */
	NSObject *tt = [self safeFetchFromArray:cert atIndex:1 withType:nil];
	NSMutableArray *tserial = [[NSMutableArray alloc] initWithCapacity:16];
	if (tt != nil && [tt isKindOfClass:[NSNumber class]]) {
		long ttn = [(NSNumber *)tt longValue];
		while (ttn > 0) {
			[tserial addObject:[NSString stringWithFormat:@"%02lx", (ttn & 0xff)]];
			ttn >>= 8;
		}
		tserial = [[NSMutableArray alloc] initWithArray:[[tserial reverseObjectEnumerator] allObjects]];
	}
	else if (tt != nil && [tt isKindOfClass:[NSData class]]) {
		u_char *tbytes = (u_char *)[(NSData *)tt bytes];
		for (int i = 0; i < [(NSData *)tt length]; i++)
			[tserial addObject:[NSString stringWithFormat:@"%02x", tbytes[i]]];
	}
	_serialNumber = [tserial componentsJoinedByString:@":"];

	/* signature algorithm (string representation - https://tools.ietf.org/html/rfc7427#page-12) */
	NSArray *sigAlgTree = [self safeFetchFromArray:cert atIndex:2 withType:[NSArray class]];
	if (sigAlgTree == nil)
		return nil;
	NSString *sigAlgOID = [self safeFetchFromArray:sigAlgTree atIndex:0 withType:[NSString class]];
	if (sigAlgOID == nil)
		return nil;
	if ([sigAlgOID isEqualToString:@"1.2.840.113549.1.1.5"])
		_signatureAlgorithm = @"sha1WithRSAEncryption";
	else if ([sigAlgOID isEqualToString:@"1.2.840.113549.1.1.11"])
		_signatureAlgorithm = @"sha256WithRSAEncryption";
	else if ([sigAlgOID isEqualToString:@"1.2.840.113549.1.1.12"])
		_signatureAlgorithm = @"sha384WithRSAEncryption";
	else if ([sigAlgOID isEqualToString:@"1.2.840.113549.1.1.13"])
		_signatureAlgorithm = @"sha512WithRSAEncryption";
	else if ([sigAlgOID isEqualToString:@"1.2.840.10040.4.3"])
		_signatureAlgorithm = @"dsa-with-sha1";
	else if ([sigAlgOID isEqualToString:@"2.16.840.1.101.3.4.3.2"])
		_signatureAlgorithm = @"dsa-with-sha256";
	else if ([sigAlgOID isEqualToString:@"1.2.840.10045.4.1"])
		_signatureAlgorithm = @"ecdsa-with-sha1";
	else if ([sigAlgOID isEqualToString:@"1.2.840.10045.4.3.2"])
		_signatureAlgorithm = @"ecdsa-with-sha256";
	else if ([sigAlgOID isEqualToString:@"1.2.840.10045.4.3.3"])
		_signatureAlgorithm = @"ecdsa-with-sha384";
	else if ([sigAlgOID isEqualToString:@"1.2.840.10045.4.3.4"])
		_signatureAlgorithm = @"ecdsa-with-sha512";
	else
		_signatureAlgorithm = [NSString stringWithFormat:@"Unknown (%@)", sigAlgOID];
	
	/* cert issuer (hash of assorted keys like locale, org, etc.) */
	NSArray *issuerData = [self safeFetchFromArray:cert atIndex:3 withType:[NSArray class]];
	if (issuerData == nil)
		return nil;
	NSMutableDictionary *tissuer = [@{} mutableCopy];
	for (int i = 0; i < [issuerData count]; i++) {
		NSArray *pairA = [self safeFetchFromArray:issuerData atIndex:i withType:[NSArray class]];
		if (pairA == nil)
			continue;
		
		for (int j = 0; j < [pairA count]; j++) {
			NSArray *oidPair = [self safeFetchFromArray:pairA atIndex:j withType:[NSArray class]];
			if (oidPair == nil)
				return nil;
			
			NSString *oid = [self safeFetchFromArray:oidPair atIndex:0 withType:[NSString class]];
			if (oid == nil)
				continue;
			NSString *val = [self safeFetchFromArray:oidPair atIndex:1 withType:[NSString class]];
			if (val == nil)
				continue;
			
			[self setOid:oid toValue:val inDictionary:tissuer];
		}
	}
	_issuer = tissuer;
	
	NSArray *validityPeriod = [self safeFetchFromArray:cert atIndex:4 withType:[NSArray class]];
	if (validityPeriod == nil)
		return nil;
	_validityNotBefore = [self safeFetchFromArray:validityPeriod atIndex:0 withType:[NSDate class]];
	if (_validityNotBefore == nil)
		return nil;
	_validityNotAfter = [self safeFetchFromArray:validityPeriod atIndex:1 withType:[NSDate class]];
	if (_validityNotAfter == nil)
		return nil;
	
	NSMutableDictionary *tsubject = [@{} mutableCopy];
	NSArray *tsubjectData = [self safeFetchFromArray:cert atIndex:5 withType:[NSArray class]];
	if (tsubjectData == nil)
		return nil;
	for (int i = 0; i < [tsubjectData count]; i++) {
		NSArray *pairA = [self safeFetchFromArray:tsubjectData atIndex:i withType:[NSArray class]];
		if (pairA == nil)
			continue;
		
		for (int j = 0; j < [pairA count]; j++) {
			NSArray *oidPair = [self safeFetchFromArray:pairA atIndex:j withType:[NSArray class]];
			if (oidPair == nil)
				return nil;
			
			NSString *oid = [self safeFetchFromArray:oidPair atIndex:0 withType:[NSString class]];
			if (oid == nil)
				continue;
			NSString *val = [self safeFetchFromArray:oidPair atIndex:1 withType:[NSString class]];
			if (val == nil)
				continue;
		
			[self setOid:oid toValue:val inDictionary:tsubject];
		}
	}
	_subject = tsubject;
	
#ifdef TRACE
	NSLog(@"[SSLCertificate] parsed certificate for %@: version=%@, serial=%@, sigalg=%@, issuer=%@, valid=%@ to %@", [_subject objectForKey:X509_KEY_CN], _version, _serialNumber, _signatureAlgorithm, [_issuer objectForKey:X509_KEY_CN], _validityNotBefore, _validityNotAfter);
#endif
	
	if ([certCache count] >= CERT_CACHE_SIZE) {
		NSArray *sortedCerts = [[certCache allKeys] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
			NSDate *da = [[certCache objectForKey:a] objectForKey:CERT_CACHE_KEY_TIME];
			NSDate *db = [[certCache objectForKey:b] objectForKey:CERT_CACHE_KEY_TIME];
			return [da compare:db];
		}];
		
		for (int i = 0; i < ([certCache count] - (CERT_CACHE_SIZE / 2)); i++)
			[certCache removeObjectForKey:[sortedCerts objectAtIndex:i]];
	}

	ocdef = [[NSMutableDictionary alloc] initWithObjectsAndKeys:self, CERT_CACHE_KEY_CERT, [NSDate date], CERT_CACHE_KEY_TIME, nil];
	[certCache setObject:ocdef forKey:certHash];
	
	return self;
}

- (BOOL)isExpired
{
	return (NSDate.date > self.validityNotAfter);
}

- (BOOL)hasWeakSignatureAlgorithm
{
	return ([self signatureAlgorithm] != nil && [[[self signatureAlgorithm] lowercaseString] containsString:@"sha1"]);
}

- (id)safeFetchFromArray:(NSArray *)arr atIndex:(NSInteger)index withType:(Class)cType
{
	if (arr == nil) {
		NSLog(@"[SSLCertificate] array is nil");
		return nil;
	}
	
	if (index > ([arr count] - 1)) {
		NSLog(@"[SSLCertificate] array count is %lu, need index %lu", (unsigned long)[arr count], (long)index);
		return nil;
	}
	
	NSObject *ret;
	@try {
		ret = [arr objectAtIndex:index];
		if (ret == nil) {
			NSLog(@"[SSLCertificate] array object at index %lu is nil", (long)index);
			return nil;
		}
	}
	@catch(NSException *e) {
		NSLog(@"[SSLCertificate] failed fetching object %lu from array: %@", (long)index, e);
		return nil;
	}
		
	if (cType != nil && ![ret isKindOfClass:cType]) {
		NSLog(@"[SSLCertificate] array object at index %lu is type %@, not %@", (long)index, NSStringFromClass([ret class]), cType);
		return nil;
	}

	return ret;
}
							      
- (void)setOid:(NSString *)oid toValue:(id)val inDictionary:(NSMutableDictionary *)dict
{
	/* TODO: what to do about conflicts?  some certs have two OUs */

	if ([oid isEqualToString:@"2.5.4.3"])
		[dict setObject:val forKey:X509_KEY_CN]; /* CN=commonName */
	else if ([oid isEqualToString:@"2.5.4.4"])
		[dict setObject:val forKey:X509_KEY_SN]; /* SN=serial */
	else if ([oid isEqualToString:@"2.5.4.5"])
		[dict setObject:val forKey:X509_KEY_SERIAL]; /* SERIALNUMBER */
	else if ([oid isEqualToString:@"2.5.4.6"])
		[dict setObject:val forKey:X509_KEY_C]; /* C=country */
	else if ([oid isEqualToString:@"2.5.4.7"])
		[dict setObject:val forKey:X509_KEY_L]; /* L=locality */
	else if ([oid isEqualToString:@"2.5.4.8"])
		[dict setObject:val forKey:X509_KEY_ST]; /* ST=state/province */
	else if ([oid isEqualToString:@"2.5.4.9"])
		[dict setObject:val forKey:X509_KEY_STREET]; /* ST=state/province */
	else if ([oid isEqualToString:@"2.5.4.10"])
		[dict setObject:val forKey:X509_KEY_O]; /* O=organization */
	else if ([oid isEqualToString:@"2.5.4.11"])
		[dict setObject:val forKey:X509_KEY_OU]; /* OU=org unit */
	else if ([oid isEqualToString:@"2.5.4.15"])
		[dict setObject:val forKey:X509_KEY_BUSCAT];
	else if ([oid isEqualToString:@"2.5.4.17"])
		[dict setObject:val forKey:X509_KEY_ZIP];

	else if (![dict objectForKey:oid])
		[dict setObject:val forKey:[NSString stringWithFormat:@"Object Identifier %@", oid]];
	
	return;
}

- (NSString *)negotiatedProtocolString
{
	switch ([self negotiatedProtocol]) {
	case kSSLProtocol2:
		return @"SSL 2.0";
	case kSSLProtocol3:
		return @"SSL 3.0";
	case kTLSProtocol1:
		return @"TLS 1.0";
	case kTLSProtocol11:
		return @"TLS 1.1";
	case kTLSProtocol12:
		return @"TLS 1.2";
	case kTLSProtocol13:
		return @"TLS 1.3";
	default:
		return [NSString stringWithFormat:@"Unknown (%d)", [self negotiatedProtocol]];
	}
}

- (NSString *)negotiatedCipherString
{
	switch ([self negotiatedCipher]) {
	case SSL_NULL_WITH_NULL_NULL:
		return @"SSL_NULL_WITH_NULL_NULL";
	case SSL_RSA_WITH_NULL_MD5:
		return @"SSL_RSA_WITH_NULL_MD5";
	case SSL_RSA_WITH_NULL_SHA:
		return @"SSL_RSA_WITH_NULL_SHA";
	case SSL_RSA_EXPORT_WITH_RC4_40_MD5:
		return @"SSL_RSA_EXPORT_WITH_RC4_40_MD5";
	case SSL_RSA_WITH_RC4_128_MD5:
		return @"SSL_RSA_WITH_RC4_128_MD5";
	case SSL_RSA_WITH_RC4_128_SHA:
		return @"SSL_RSA_WITH_RC4_128_SHA";
	case SSL_RSA_EXPORT_WITH_RC2_CBC_40_MD5:
		return @"SSL_RSA_EXPORT_WITH_RC2_CBC_40_MD5";
	case SSL_RSA_WITH_IDEA_CBC_SHA:
		return @"SSL_RSA_WITH_IDEA_CBC_SHA";
	case SSL_RSA_EXPORT_WITH_DES40_CBC_SHA:
		return @"SSL_RSA_EXPORT_WITH_DES40_CBC_SHA";
	case SSL_RSA_WITH_DES_CBC_SHA:
		return @"SSL_RSA_WITH_DES_CBC_SHA";
	case SSL_RSA_WITH_3DES_EDE_CBC_SHA:
		return @"SSL_RSA_WITH_3DES_EDE_CBC_SHA";
	case SSL_DH_DSS_EXPORT_WITH_DES40_CBC_SHA:
		return @"SSL_DH_DSS_EXPORT_WITH_DES40_CBC_SHA";
	case SSL_DH_DSS_WITH_DES_CBC_SHA:
		return @"SSL_DH_DSS_WITH_DES_CBC_SHA";
	case SSL_DH_DSS_WITH_3DES_EDE_CBC_SHA:
		return @"SSL_DH_DSS_WITH_3DES_EDE_CBC_SHA";
	case SSL_DH_RSA_EXPORT_WITH_DES40_CBC_SHA:
		return @"SSL_DH_RSA_EXPORT_WITH_DES40_CBC_SHA";
	case SSL_DH_RSA_WITH_DES_CBC_SHA:
		return @"SSL_DH_RSA_WITH_DES_CBC_SHA";
	case SSL_DH_RSA_WITH_3DES_EDE_CBC_SHA:
		return @"SSL_DH_RSA_WITH_3DES_EDE_CBC_SHA";
	case SSL_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA:
		return @"SSL_DHE_DSS_EXPORT_WITH_DES40_CBC_SHA";
	case SSL_DHE_DSS_WITH_DES_CBC_SHA:
		return @"SSL_DHE_DSS_WITH_DES_CBC_SHA";
	case SSL_DHE_DSS_WITH_3DES_EDE_CBC_SHA:
		return @"SSL_DHE_DSS_WITH_3DES_EDE_CBC_SHA";
	case SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA:
		return @"SSL_DHE_RSA_EXPORT_WITH_DES40_CBC_SHA";
	case SSL_DHE_RSA_WITH_DES_CBC_SHA:
		return @"SSL_DHE_RSA_WITH_DES_CBC_SHA";
	case SSL_DHE_RSA_WITH_3DES_EDE_CBC_SHA:
		return @"SSL_DHE_RSA_WITH_3DES_EDE_CBC_SHA";
	case SSL_DH_anon_EXPORT_WITH_RC4_40_MD5:
		return @"SSL_DH_anon_EXPORT_WITH_RC4_40_MD5";
	case SSL_DH_anon_WITH_RC4_128_MD5:
		return @"SSL_DH_anon_WITH_RC4_128_MD5";
	case SSL_DH_anon_EXPORT_WITH_DES40_CBC_SHA:
		return @"SSL_DH_anon_EXPORT_WITH_DES40_CBC_SHA";
	case SSL_DH_anon_WITH_DES_CBC_SHA:
		return @"SSL_DH_anon_WITH_DES_CBC_SHA";
	case SSL_DH_anon_WITH_3DES_EDE_CBC_SHA:
		return @"SSL_DH_anon_WITH_3DES_EDE_CBC_SHA";
	case SSL_FORTEZZA_DMS_WITH_NULL_SHA:
		return @"SSL_FORTEZZA_DMS_WITH_NULL_SHA";
	case SSL_FORTEZZA_DMS_WITH_FORTEZZA_CBC_SHA:
		return @"SSL_FORTEZZA_DMS_WITH_FORTEZZA_CBC_SHA";
	case TLS_RSA_WITH_AES_128_CBC_SHA:
		return @"TLS_RSA_WITH_AES_128_CBC_SHA";
	case TLS_DH_DSS_WITH_AES_128_CBC_SHA:
		return @"TLS_DH_DSS_WITH_AES_128_CBC_SHA";
	case TLS_DH_RSA_WITH_AES_128_CBC_SHA:
		return @"TLS_DH_RSA_WITH_AES_128_CBC_SHA";
	case TLS_DHE_DSS_WITH_AES_128_CBC_SHA:
		return @"TLS_DHE_DSS_WITH_AES_128_CBC_SHA";
	case TLS_DHE_RSA_WITH_AES_128_CBC_SHA:
		return @"TLS_DHE_RSA_WITH_AES_128_CBC_SHA";
	case TLS_DH_anon_WITH_AES_128_CBC_SHA:
		return @"TLS_DH_anon_WITH_AES_128_CBC_SHA";
	case TLS_RSA_WITH_AES_256_CBC_SHA:
		return @"TLS_RSA_WITH_AES_256_CBC_SHA";
	case TLS_DH_DSS_WITH_AES_256_CBC_SHA:
		return @"TLS_DH_DSS_WITH_AES_256_CBC_SHA";
	case TLS_DH_RSA_WITH_AES_256_CBC_SHA:
		return @"TLS_DH_RSA_WITH_AES_256_CBC_SHA";
	case TLS_DHE_DSS_WITH_AES_256_CBC_SHA:
		return @"TLS_DHE_DSS_WITH_AES_256_CBC_SHA";
	case TLS_DHE_RSA_WITH_AES_256_CBC_SHA:
		return @"TLS_DHE_RSA_WITH_AES_256_CBC_SHA";
	case TLS_DH_anon_WITH_AES_256_CBC_SHA:
		return @"TLS_DH_anon_WITH_AES_256_CBC_SHA";
	case TLS_ECDH_ECDSA_WITH_NULL_SHA:
		return @"TLS_ECDH_ECDSA_WITH_NULL_SHA";
	case TLS_ECDH_ECDSA_WITH_RC4_128_SHA:
		return @"TLS_ECDH_ECDSA_WITH_RC4_128_SHA";
	case TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_ECDH_ECDSA_WITH_3DES_EDE_CBC_SHA";
	case TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA:
		return @"TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA";
	case TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA:
		return @"TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA";
	case TLS_ECDHE_ECDSA_WITH_NULL_SHA:
		return @"TLS_ECDHE_ECDSA_WITH_NULL_SHA";
	case TLS_ECDHE_ECDSA_WITH_RC4_128_SHA:
		return @"TLS_ECDHE_ECDSA_WITH_RC4_128_SHA";
	case TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_ECDHE_ECDSA_WITH_3DES_EDE_CBC_SHA";
	case TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA:
		return @"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA";
	case TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA:
		return @"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA";
	case TLS_ECDH_RSA_WITH_NULL_SHA:
		return @"TLS_ECDH_RSA_WITH_NULL_SHA";
	case TLS_ECDH_RSA_WITH_RC4_128_SHA:
		return @"TLS_ECDH_RSA_WITH_RC4_128_SHA";
	case TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_ECDH_RSA_WITH_3DES_EDE_CBC_SHA";
	case TLS_ECDH_RSA_WITH_AES_128_CBC_SHA:
		return @"TLS_ECDH_RSA_WITH_AES_128_CBC_SHA";
	case TLS_ECDH_RSA_WITH_AES_256_CBC_SHA:
		return @"TLS_ECDH_RSA_WITH_AES_256_CBC_SHA";
	case TLS_ECDHE_RSA_WITH_NULL_SHA:
		return @"TLS_ECDHE_RSA_WITH_NULL_SHA";
	case TLS_ECDHE_RSA_WITH_RC4_128_SHA:
		return @"TLS_ECDHE_RSA_WITH_RC4_128_SHA";
	case TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_ECDHE_RSA_WITH_3DES_EDE_CBC_SHA";
	case TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA:
		return @"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA";
	case TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA:
		return @"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA";
	case TLS_ECDH_anon_WITH_NULL_SHA:
		return @"TLS_ECDH_anon_WITH_NULL_SHA";
	case TLS_ECDH_anon_WITH_RC4_128_SHA:
		return @"TLS_ECDH_anon_WITH_RC4_128_SHA";
	case TLS_ECDH_anon_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_ECDH_anon_WITH_3DES_EDE_CBC_SHA";
	case TLS_ECDH_anon_WITH_AES_128_CBC_SHA:
		return @"TLS_ECDH_anon_WITH_AES_128_CBC_SHA";
	case TLS_ECDH_anon_WITH_AES_256_CBC_SHA:
		return @"TLS_ECDH_anon_WITH_AES_256_CBC_SHA";
#if 0
	case TLS_NULL_WITH_NULL_NULL:
		return @"TLS_NULL_WITH_NULL_NULL";
	case TLS_RSA_WITH_NULL_MD5:
		return @"TLS_RSA_WITH_NULL_MD5";
	case TLS_RSA_WITH_NULL_SHA:
		return @"TLS_RSA_WITH_NULL_SHA";
	case TLS_RSA_WITH_RC4_128_MD5:
		return @"TLS_RSA_WITH_RC4_128_MD5";
	case TLS_RSA_WITH_RC4_128_SHA:
		return @"TLS_RSA_WITH_RC4_128_SHA";
	case TLS_RSA_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_RSA_WITH_3DES_EDE_CBC_SHA";
#endif
	case TLS_RSA_WITH_NULL_SHA256:
		return @"TLS_RSA_WITH_NULL_SHA256";
	case TLS_RSA_WITH_AES_128_CBC_SHA256:
		return @"TLS_RSA_WITH_AES_128_CBC_SHA256";
	case TLS_RSA_WITH_AES_256_CBC_SHA256:
		return @"TLS_RSA_WITH_AES_256_CBC_SHA256";
#if 0
	case TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_DH_DSS_WITH_3DES_EDE_CBC_SHA";
	case TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_DH_RSA_WITH_3DES_EDE_CBC_SHA";
	case TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_DHE_DSS_WITH_3DES_EDE_CBC_SHA";
	case TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_DHE_RSA_WITH_3DES_EDE_CBC_SHA";
#endif
	case TLS_DH_DSS_WITH_AES_128_CBC_SHA256:
		return @"TLS_DH_DSS_WITH_AES_128_CBC_SHA256";
	case TLS_DH_RSA_WITH_AES_128_CBC_SHA256:
		return @"TLS_DH_RSA_WITH_AES_128_CBC_SHA256";
	case TLS_DHE_DSS_WITH_AES_128_CBC_SHA256:
		return @"TLS_DHE_DSS_WITH_AES_128_CBC_SHA256";
	case TLS_DHE_RSA_WITH_AES_128_CBC_SHA256:
		return @"TLS_DHE_RSA_WITH_AES_128_CBC_SHA256";
	case TLS_DH_DSS_WITH_AES_256_CBC_SHA256:
		return @"TLS_DH_DSS_WITH_AES_256_CBC_SHA256";
	case TLS_DH_RSA_WITH_AES_256_CBC_SHA256:
		return @"TLS_DH_RSA_WITH_AES_256_CBC_SHA256";
	case TLS_DHE_DSS_WITH_AES_256_CBC_SHA256:
		return @"TLS_DHE_DSS_WITH_AES_256_CBC_SHA256";
	case TLS_DHE_RSA_WITH_AES_256_CBC_SHA256:
		return @"TLS_DHE_RSA_WITH_AES_256_CBC_SHA256";
#if 0
	case TLS_DH_anon_WITH_RC4_128_MD5:
		return @"TLS_DH_anon_WITH_RC4_128_MD5";
	case TLS_DH_anon_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_DH_anon_WITH_3DES_EDE_CBC_SHA";
#endif
	case TLS_DH_anon_WITH_AES_128_CBC_SHA256:
		return @"TLS_DH_anon_WITH_AES_128_CBC_SHA256";
	case TLS_DH_anon_WITH_AES_256_CBC_SHA256:
		return @"TLS_DH_anon_WITH_AES_256_CBC_SHA256";
	case TLS_PSK_WITH_RC4_128_SHA:
		return @"TLS_PSK_WITH_RC4_128_SHA";
	case TLS_PSK_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_PSK_WITH_3DES_EDE_CBC_SHA";
	case TLS_PSK_WITH_AES_128_CBC_SHA:
		return @"TLS_PSK_WITH_AES_128_CBC_SHA";
	case TLS_PSK_WITH_AES_256_CBC_SHA:
		return @"TLS_PSK_WITH_AES_256_CBC_SHA";
	case TLS_DHE_PSK_WITH_RC4_128_SHA:
		return @"TLS_DHE_PSK_WITH_RC4_128_SHA";
	case TLS_DHE_PSK_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_DHE_PSK_WITH_3DES_EDE_CBC_SHA";
	case TLS_DHE_PSK_WITH_AES_128_CBC_SHA:
		return @"TLS_DHE_PSK_WITH_AES_128_CBC_SHA";
	case TLS_DHE_PSK_WITH_AES_256_CBC_SHA:
		return @"TLS_DHE_PSK_WITH_AES_256_CBC_SHA";
	case TLS_RSA_PSK_WITH_RC4_128_SHA:
		return @"TLS_RSA_PSK_WITH_RC4_128_SHA";
	case TLS_RSA_PSK_WITH_3DES_EDE_CBC_SHA:
		return @"TLS_RSA_PSK_WITH_3DES_EDE_CBC_SHA";
	case TLS_RSA_PSK_WITH_AES_128_CBC_SHA:
		return @"TLS_RSA_PSK_WITH_AES_128_CBC_SHA";
	case TLS_RSA_PSK_WITH_AES_256_CBC_SHA:
		return @"TLS_RSA_PSK_WITH_AES_256_CBC_SHA";
	case TLS_PSK_WITH_NULL_SHA:
		return @"TLS_PSK_WITH_NULL_SHA";
	case TLS_DHE_PSK_WITH_NULL_SHA:
		return @"TLS_DHE_PSK_WITH_NULL_SHA";
	case TLS_RSA_PSK_WITH_NULL_SHA:
		return @"TLS_RSA_PSK_WITH_NULL_SHA";
	case TLS_RSA_WITH_AES_128_GCM_SHA256:
		return @"TLS_RSA_WITH_AES_128_GCM_SHA256";
	case TLS_RSA_WITH_AES_256_GCM_SHA384:
		return @"TLS_RSA_WITH_AES_256_GCM_SHA384";
	case TLS_DHE_RSA_WITH_AES_128_GCM_SHA256:
		return @"TLS_DHE_RSA_WITH_AES_128_GCM_SHA256";
	case TLS_DHE_RSA_WITH_AES_256_GCM_SHA384:
		return @"TLS_DHE_RSA_WITH_AES_256_GCM_SHA384";
	case TLS_DH_RSA_WITH_AES_128_GCM_SHA256:
		return @"TLS_DH_RSA_WITH_AES_128_GCM_SHA256";
	case TLS_DH_RSA_WITH_AES_256_GCM_SHA384:
		return @"TLS_DH_RSA_WITH_AES_256_GCM_SHA384";
	case TLS_DHE_DSS_WITH_AES_128_GCM_SHA256:
		return @"TLS_DHE_DSS_WITH_AES_128_GCM_SHA256";
	case TLS_DHE_DSS_WITH_AES_256_GCM_SHA384:
		return @"TLS_DHE_DSS_WITH_AES_256_GCM_SHA384";
	case TLS_DH_DSS_WITH_AES_128_GCM_SHA256:
		return @"TLS_DH_DSS_WITH_AES_128_GCM_SHA256";
	case TLS_DH_DSS_WITH_AES_256_GCM_SHA384:
		return @"TLS_DH_DSS_WITH_AES_256_GCM_SHA384";
	case TLS_DH_anon_WITH_AES_128_GCM_SHA256:
		return @"TLS_DH_anon_WITH_AES_128_GCM_SHA256";
	case TLS_DH_anon_WITH_AES_256_GCM_SHA384:
		return @"TLS_DH_anon_WITH_AES_256_GCM_SHA384";
	case TLS_PSK_WITH_AES_128_GCM_SHA256:
		return @"TLS_PSK_WITH_AES_128_GCM_SHA256";
	case TLS_PSK_WITH_AES_256_GCM_SHA384:
		return @"TLS_PSK_WITH_AES_256_GCM_SHA384";
	case TLS_DHE_PSK_WITH_AES_128_GCM_SHA256:
		return @"TLS_DHE_PSK_WITH_AES_128_GCM_SHA256";
	case TLS_DHE_PSK_WITH_AES_256_GCM_SHA384:
		return @"TLS_DHE_PSK_WITH_AES_256_GCM_SHA384";
	case TLS_RSA_PSK_WITH_AES_128_GCM_SHA256:
		return @"TLS_RSA_PSK_WITH_AES_128_GCM_SHA256";
	case TLS_RSA_PSK_WITH_AES_256_GCM_SHA384:
		return @"TLS_RSA_PSK_WITH_AES_256_GCM_SHA384";
	case TLS_PSK_WITH_AES_128_CBC_SHA256:
		return @"TLS_PSK_WITH_AES_128_CBC_SHA256";
	case TLS_PSK_WITH_AES_256_CBC_SHA384:
		return @"TLS_PSK_WITH_AES_256_CBC_SHA384";
	case TLS_PSK_WITH_NULL_SHA256:
		return @"TLS_PSK_WITH_NULL_SHA256";
	case TLS_PSK_WITH_NULL_SHA384:
		return @"TLS_PSK_WITH_NULL_SHA384";
	case TLS_DHE_PSK_WITH_AES_128_CBC_SHA256:
		return @"TLS_DHE_PSK_WITH_AES_128_CBC_SHA256";
	case TLS_DHE_PSK_WITH_AES_256_CBC_SHA384:
		return @"TLS_DHE_PSK_WITH_AES_256_CBC_SHA384";
	case TLS_DHE_PSK_WITH_NULL_SHA256:
		return @"TLS_DHE_PSK_WITH_NULL_SHA256";
	case TLS_DHE_PSK_WITH_NULL_SHA384:
		return @"TLS_DHE_PSK_WITH_NULL_SHA384";
	case TLS_RSA_PSK_WITH_AES_128_CBC_SHA256:
		return @"TLS_RSA_PSK_WITH_AES_128_CBC_SHA256";
	case TLS_RSA_PSK_WITH_AES_256_CBC_SHA384:
		return @"TLS_RSA_PSK_WITH_AES_256_CBC_SHA384";
	case TLS_RSA_PSK_WITH_NULL_SHA256:
		return @"TLS_RSA_PSK_WITH_NULL_SHA256";
	case TLS_RSA_PSK_WITH_NULL_SHA384:
		return @"TLS_RSA_PSK_WITH_NULL_SHA384";
	case TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256:
		return @"TLS_ECDHE_ECDSA_WITH_AES_128_CBC_SHA256";
	case TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384:
		return @"TLS_ECDHE_ECDSA_WITH_AES_256_CBC_SHA384";
	case TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256:
		return @"TLS_ECDH_ECDSA_WITH_AES_128_CBC_SHA256";
	case TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384:
		return @"TLS_ECDH_ECDSA_WITH_AES_256_CBC_SHA384";
	case TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256:
		return @"TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256";
	case TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384:
		return @"TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384";
	case TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256:
		return @"TLS_ECDH_RSA_WITH_AES_128_CBC_SHA256";
	case TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384:
		return @"TLS_ECDH_RSA_WITH_AES_256_CBC_SHA384";
	case TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256:
		return @"TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256";
	case TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384:
		return @"TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384";
	case TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256:
		return @"TLS_ECDH_ECDSA_WITH_AES_128_GCM_SHA256";
	case TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384:
		return @"TLS_ECDH_ECDSA_WITH_AES_256_GCM_SHA384";
	case TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256:
		return @"TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256";
	case TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384:
		return @"TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384";
	case TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256:
		return @"TLS_ECDH_RSA_WITH_AES_128_GCM_SHA256";
	case TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384:
		return @"TLS_ECDH_RSA_WITH_AES_256_GCM_SHA384";
	case TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256:
		return @"TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256";
	case TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256:
		return @"TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256";
	case TLS_EMPTY_RENEGOTIATION_INFO_SCSV:
		return @"TLS_EMPTY_RENEGOTIATION_INFO_SCSV";
	case SSL_RSA_WITH_RC2_CBC_MD5:
		return @"SSL_RSA_WITH_RC2_CBC_MD5";
	case SSL_RSA_WITH_IDEA_CBC_MD5:
		return @"SSL_RSA_WITH_IDEA_CBC_MD5";
	case SSL_RSA_WITH_DES_CBC_MD5:
		return @"SSL_RSA_WITH_DES_CBC_MD5";
	case SSL_RSA_WITH_3DES_EDE_CBC_MD5:
		return @"SSL_RSA_WITH_3DES_EDE_CBC_MD5";
	case SSL_NO_SUCH_CIPHERSUITE:
		return @"SSL_NO_SUCH_CIPHERSUITE";
	default:
		return [NSString stringWithFormat:@"Unknown (%d)", [self negotiatedCipher]];
	}
}

@end
