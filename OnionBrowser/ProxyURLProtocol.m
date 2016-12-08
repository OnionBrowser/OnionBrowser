// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "ProxyURLProtocol.h"
#import <Foundation/NSURLProtocol.h>
#import "AppDelegate.h"
#import "NSData+CocoaDevUsersAdditions.h"


@implementation ProxyURLProtocol

// Accessors

- (CKHTTPConnection *)connection {
    return _connection;
}

- (void)setConnection:(CKHTTPConnection *)value {
    if (_connection != value) {
        _connection = value;
    }
}

-(id)initWithRequest:(NSURLRequest *)request
      cachedResponse:(NSCachedURLResponse *)cachedResponse
              client:(id <NSURLProtocolClient>)client {

    incomingContentType = PROXY_CONTENT_OTHER;
    firstChunk = YES;

    // Modify request
    NSMutableURLRequest *myRequest = [request mutableCopy];

    self = [super initWithRequest:myRequest
                   cachedResponse:cachedResponse
                           client:client];
    if ( self ) {
        [self setRequest:myRequest];
    }
    return self;
}

- (NSURLRequest *)request {
    return _request;
}

- (void)setRequest:(NSURLRequest *)value {
    if (_request != value) {
        _request = value;
    }
}

- (NSMutableData *)data {
    return _data;
}

- (void)appendData:(NSData *)newData {
    if( _data == nil ) {
        _data = [[NSMutableData alloc] initWithData:newData];
    } else {
        [_data appendData:newData];
    }
}

// Class methods

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ( !([[[[request URL] scheme] lowercaseString] isEqualToString:@"file"] ||
           [[[[request URL] scheme] lowercaseString] isEqualToString:@"data"]
           )
    ) {
        // Previously we checked if it matched "http" or "https". Apparently
        // UIWebView can attempt to make FTP connections for HTML page resources (i.e.
        // a <link> tag for a CSS file with an FTP scheme.). So we whitelist
        // file:// and data:// urls and attempt to tunnel everything else over Tor.
        return YES;
    } else {
        return NO;
    }
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}



- (void)startLoading {
    if ([[[[[self request] URL] scheme] lowercaseString] isEqualToString:@"onionbrowser"]) {
        NSURL *url;
        NSString *resourcePath = [[NSBundle mainBundle] resourcePath];
        resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@"/" withString:@"//"];
        resourcePath = [resourcePath stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
        if ([[[[self request] URL] absoluteString] rangeOfString:@"about"].location != NSNotFound) {
            /* onionbrowser:about */
            url = [NSURL URLWithString: [NSString stringWithFormat:@"file:/%@/about.html",resourcePath]];
        } else if ([[[[self request] URL] absoluteString] rangeOfString:@"start2"].location != NSNotFound) {
            /* onionbrowser:start2 -- inner iframe banner */
            url = [NSURL URLWithString: [NSString stringWithFormat:@"file:/%@/startup2.html",resourcePath]];
        } else if ([[[[self request] URL] absoluteString] rangeOfString:@"icon"].location != NSNotFound) {
            /* onionbrowser:icon */
            url = [NSURL URLWithString: [NSString stringWithFormat:@"file:/%@/AppIcon57x57@2x.png",resourcePath]];
        } else if ([[[[self request] URL] absoluteString] rangeOfString:@"help"].location != NSNotFound) {
            /* onionbrowser:help */
            url = [NSURL URLWithString: [NSString stringWithFormat:@"file:/%@/help.html",resourcePath]];
        } else if ([[[[self request] URL] absoluteString] rangeOfString:@"patreon.png"].location != NSNotFound) {
            /* onionbrowser:patreon.png -- inner iframe banner */
            url = [NSURL URLWithString: [NSString stringWithFormat:@"file:/%@/patreon.png",resourcePath]];
        } else {
            /* onionbrowser:home */
            url = [NSURL URLWithString: [NSString stringWithFormat:@"file:/%@/startup.html",resourcePath]];
        }
        NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:url];
        [newRequest setAllHTTPHeaderFields:[[self request] allHTTPHeaderFields]];
        NSURLConnection *con = [NSURLConnection connectionWithRequest:newRequest delegate:self];
        [self setConnection:(CKHTTPConnection *)con]; // lie.
    } else if ([[[[[self request] URL] scheme] lowercaseString] isEqualToString:@"about"]) {
        //only support about:blank
        NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]];
        [newRequest setAllHTTPHeaderFields:[[self request] allHTTPHeaderFields]];
        NSURLConnection *con = [NSURLConnection connectionWithRequest:newRequest delegate:self];
        [self setConnection:(CKHTTPConnection *)con]; // lie.
    } else {
        CKHTTPConnection *con = [CKHTTPConnection connectionWithRequest:[self request] delegate:self];
        [self setConnection:con];
    }
}

-(void)stopLoading {
    [[self connection] cancel];
}


#pragma mark -
#pragma mark NSURLConnectionDelegate

- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response {
    if (response != nil) {
        [[self client] URLProtocol:self wasRedirectedToRequest:request redirectResponse:response];
    }
    return request;
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
    [self appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
	[self setConnection:nil];
	 _data = nil;
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if( _data != nil ) {
        _data = nil;
    }
    _data.length = 0;

    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
	[self setConnection:nil];
	 _data = nil;
}


#pragma mark -
#pragma mark CKHTTPConnectionDelegate


- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self.client URLProtocol:self didReceiveAuthenticationChallenge:challenge];
}
- (void)HTTPConnection:(CKHTTPConnection *)connection didCancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self.client URLProtocol:self didCancelAuthenticationChallenge:challenge];
}
- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveResponse:(NSHTTPURLResponse *)response {
    isGzippedResponse = NO;
    #ifdef DEBUG
        NSLog(@"[ProxyURLProtocol] Got response %ld: content-type: %@", (long)[response statusCode], [response MIMEType]);
    #endif
    if( _data != nil ) {
        _data = nil;
    }
    _data.length = 0;

    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSMutableDictionary *settings = appDelegate.getSettings;

    if ([[[[_request mainDocumentURL] scheme] lowercaseString] isEqualToString:@"https"] && ![[[[response URL] scheme] lowercaseString] isEqualToString:@"https"]) {
      [appDelegate.appWebView updateTLSStatus:TLSSTATUS_INSECURE];
    }

    /* If this incoming request is HTML or Javascript (based on content-type header),
     * flag it for processing later. (We'll prepend some JS to try to rewrite navigator.useragent,
     * block WebSockets), etc.)
     */
    for(id h in response.allHeaderFields) {
        if([[h lowercaseString] isEqualToString:@"content-type"]) {
            NSString *ctype = [response.allHeaderFields objectForKey:h];
            if ([ctype hasPrefix:@"text/html"] || [ctype hasPrefix:@"application/html"] || [ctype hasPrefix:@"application/xhtml+xml"]) {
                incomingContentType = PROXY_CONTENT_HTML;
            } else if ([ctype hasPrefix:@"application/javascript"] || [ctype hasPrefix:@"text/javascript"] || [ctype hasPrefix:@"application/x-javascript"] || [ctype hasPrefix:@"text/x-javascript"]) {
                incomingContentType = PROXY_CONTENT_JS;
            }
            break;
        }
    }

    /* If content-policy ("javascript") setting is CONTENTPOLICY_STRICT or CONTENTPOLICY_BLOCK_CONNECT,
     * modify incoming headers to turn on the "content-security-policy" and "x-webkit-csp" headers accordingly.
     * http://www.html5rocks.com/en/tutorials/security/content-security-policy/#policy-applies-to-a-wide-variety-of-resources
     * http://www.w3.org/TR/CSP/
     */
    if (([[settings valueForKey:@"javascript"] integerValue] == CONTENTPOLICY_STRICT)
        && ([response isKindOfClass: [NSHTTPURLResponse class]] == YES)) {
        // In the STRICT case, we're going to drop any content-security-policy headers since we just want
        // our strictest-possible header.
        NSMutableDictionary *mHeaders = [NSMutableDictionary dictionary];
        for(id h in response.allHeaderFields) {
            if(![[h lowercaseString] isEqualToString:@"content-security-policy"] && ![[h lowercaseString] isEqualToString:@"x-webkit-csp"]) {
                // Delete existing content-security-policy headers (since we rely on writing our on strict ones)
                [mHeaders setObject:response.allHeaderFields[h] forKey:h];
            }
        }
        [mHeaders setObject:@"script-src 'none';media-src 'none';object-src 'none';connect-src 'none';font-src 'none';sandbox allow-forms allow-top-navigation;style-src 'unsafe-inline' *;"
                     forKey:@"Content-Security-Policy"];
        [mHeaders setObject:@"script-src 'none';media-src 'none';object-src 'none';connect-src 'none';font-src 'none';sandbox allow-forms allow-top-navigation;style-src 'unsafe-inline' *;"
                     forKey:@"X-Webkit-CSP"];
        response = [[NSHTTPURLResponse alloc]
                    initWithURL:response.URL statusCode:response.statusCode
                    HTTPVersion:@"1.1" headerFields:mHeaders];
    } else if (([[settings valueForKey:@"javascript"] integerValue] == CONTENTPOLICY_BLOCK_CONNECT)
               && ([response isKindOfClass: [NSHTTPURLResponse class]] == YES)){
        // In the "block XHR/Media/WebSocket" case, we'll prepend
        // "connect-src 'none';media-src 'none';object-src 'none';"
        // to an existing CSP header OR we'll add that header if there isn't already an existing one.
        // (Basically as the STRICT case, but allowing script/fonts.)
        NSMutableDictionary *mHeaders = [NSMutableDictionary dictionary];
        Boolean editedCSP = NO;
        Boolean editedWebkitCSP = NO;
        for(id h in response.allHeaderFields) {
            if([[h lowercaseString] isEqualToString:@"content-security-policy"]) {
                NSString *newHeader = [NSString stringWithFormat:@"connect-src 'none';media-src 'none';object-src 'none';%@", response.allHeaderFields[h]];
                [mHeaders setObject:newHeader forKey:h];
                editedCSP = YES;
            } else if ([[h lowercaseString] isEqualToString:@"x-webkit-csp"]) {
                NSString *newHeader = [NSString stringWithFormat:@"connect-src 'none';media-src 'none';object-src 'none';%@", response.allHeaderFields[h]];
                [mHeaders setObject:newHeader forKey:h];
                editedWebkitCSP = YES;
            } else {
                // Non-CSP header, just pass it on.
                [mHeaders setObject:response.allHeaderFields[h] forKey:h];
            }
        }
        if (!editedCSP) {
            [mHeaders setObject:@"connect-src 'none';media-src 'none';object-src 'none';"
                         forKey:@"Content-Security-Policy"];
        }
        if (!editedWebkitCSP) {
            [mHeaders setObject:@"connect-src 'none';media-src 'none';object-src 'none';"
                         forKey:@"X-Webkit-CSP"];
        }
        response = [[NSHTTPURLResponse alloc]
                    initWithURL:response.URL statusCode:response.statusCode
                    HTTPVersion:@"1.1" headerFields:mHeaders];
    }
    /* End header modification */


    /* We have to handle cookies manually too. (Lower in the stack -- i.e. in CKHTTPConnection -- we don't have
     * context regarding current request, such as what the current document URL is, which is what we need to
     * determine if something is a third-party URL or not.) Derived from original NSURLProtocol.m sources. */
    #ifdef DEBUG
        NSURLRequest* request = [self request];
        NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
        NSLog(@"beginning cookie routine for URL %@ (main document %@)\ncurrent cookies=%@", request.URL.absoluteString, request.mainDocumentURL.absoluteString, cookies);
    #endif
    if ([_request HTTPShouldHandleCookies] == YES
		&& [response isKindOfClass: [NSHTTPURLResponse class]] == YES)
    {
        NSDictionary	*hdrs;
        NSArray	*cookies;
        NSURL		*url;

        url = [response URL];
        hdrs = [response allHeaderFields];
        cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: hdrs
                                                         forURL: url];

        #ifdef DEBUG
            NSHTTPCookieAcceptPolicy currentCookieStatus = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookieAcceptPolicy];
            if (currentCookieStatus == NSHTTPCookieAcceptPolicyAlways) {
                NSLog(@"policy: NSHTTPCookieAcceptPolicyAlways");
            } else if (currentCookieStatus == NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain) {
                NSLog(@"policy: NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain");
            } else {
                NSLog(@"policy: NSHTTPCookieAcceptPolicyNever");
            }
            NSLog(@"attempting to set cookies\n%@", cookies);
        #endif

        [[NSHTTPCookieStorage sharedHTTPCookieStorage]
         setCookies: cookies
         forURL: url
         mainDocumentURL: [_request mainDocumentURL]];

        NSMutableDictionary *mHeaders = [NSMutableDictionary dictionary];
        for(id h in response.allHeaderFields) {
            if(![[h lowercaseString] isEqualToString:@"set-cookie"]) {
                // Delete cookie headers now that we've scooped them up
                [mHeaders setObject:response.allHeaderFields[h] forKey:h];
            }
        }
        response = [[NSHTTPURLResponse alloc]
                    initWithURL:response.URL statusCode:response.statusCode
                    HTTPVersion:@"1.1" headerFields:mHeaders];
    }
    #ifdef DEBUG
        NSArray *cookies_now = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
        NSLog(@"finished cookie routine for URL %@ (main document %@)\ncurrent cookies=%@", request.URL.absoluteString, request.mainDocumentURL.absoluteString, cookies_now);
    #endif
    /* End cookies */


    /* Handle redirects */
    if ((response.statusCode == 301)||(response.statusCode == 302)||(response.statusCode == 307)) {
        NSString *newURL = [[response allHeaderFields] objectForKey:@"Location"];
        #ifdef DEBUG
            NSLog(@"[ProxyURLProtocol] Got %ld redirect from %@ to %@", (long)response.statusCode, _request.URL, newURL);
        #endif

        NSMutableURLRequest *newRequest = [_request mutableCopy];
        [newRequest setHTTPShouldUsePipelining:YES];
        newRequest.URL = [NSURL URLWithString:newURL relativeToURL:_request.URL];
        if ([[_request mainDocumentURL] isEqual:[_request URL]]) {
          // Previous request *was* the maindocument request.
          newRequest.mainDocumentURL = newRequest.URL;
        }

        _request = newRequest;

        if ([[_request mainDocumentURL] isEqual:[_request URL]]) {
          // Main document changed, double-check secure content status
          if ([[[[_request mainDocumentURL] scheme] lowercaseString] isEqualToString:@"https"]) {
            [appDelegate.appWebView updateTLSStatus:TLSSTATUS_YES];
          } else {
            [appDelegate.appWebView updateTLSStatus:TLSSTATUS_NO];
          }
        }

        [[self client] URLProtocol:self wasRedirectedToRequest:_request redirectResponse:response];
    }


    // For some reason, passing the response directly doesn't always properly
    // set the separate mimetype and content-encoding bits, so attempt to parse
    // these out. (We'll basically always get Content-Type unless something is
    // terribly wrong.)
    //TODO: catch missing content-type (default to text/plain)
    NSString *content_type = [[response allHeaderFields] objectForKey:@"Content-Type"];
    NSArray *content_type_bits = [content_type componentsSeparatedByString:@";"];
    if ([content_type_bits count] == 0) {
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
    } else {
        NSString *mime = [content_type_bits objectAtIndex:0];
        NSString *encoding = @"UTF-8";
        NSString *content_encoding = [[response allHeaderFields] objectForKey:@"Content-Encoding"];
        if ([content_encoding isEqualToString:@"gzip"]) {
            isGzippedResponse = YES;
        }
        NSArray *charset_bits = [content_type componentsSeparatedByString:@"charset="];
        if ([charset_bits count] > 1) {
            encoding = [charset_bits objectAtIndex:1];
        }
        #ifdef DEBUG
            NSLog(@"[ProxyURLProtocol] parsed content-type=%@, encoding=%@, content_encoding=%@", mime, encoding, content_encoding);
        #endif
        NSURLResponse *textResponse;
        if ([[[[response URL] scheme] lowercaseString] isEqualToString:@"http"] || [[[[response URL] scheme] lowercaseString] isEqualToString:@"https"]) {
            textResponse = [[NSHTTPURLResponse alloc] initWithURL:response.URL statusCode:response.statusCode HTTPVersion:@"1.1" headerFields:[response allHeaderFields]];
        } else {
            textResponse = [[NSURLResponse alloc] initWithURL:response.URL MIMEType:mime expectedContentLength:(NSInteger)response.expectedContentLength textEncodingName:encoding];
        }
        [self.client URLProtocol:self didReceiveResponse:textResponse cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
    }
}
- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveData:(NSData *)data {
    [self appendData:data];
    if (isGzippedResponse) {
        // Try to un-gzip the data we've received so far.
        // If we get nil (it's incomplete gzip data), continue to
        // buffer it before passing it along. If we *can* ungzip it,
        // pass the ugzip'd data along and reset the buffer.
        NSData *newData = [_data gzipInflate];
        if (newData != nil) {
            if (firstChunk) {
                // If this is the start of the content of this (gzipped) file, inject any
                // script-overriding code as necessary.
                if (incomingContentType == PROXY_CONTENT_HTML) {
                    data = [self htmlDataWithJavascriptInjection:data];
                } else if (incomingContentType == PROXY_CONTENT_JS) {
                    data = [self javascriptDataWithJavascriptInjection:data];
                }
                // Don't do this injection the next time around
                firstChunk = NO;
            }

            [self.client URLProtocol:self didLoadData:newData];
            _data = nil;
        }
    } else {
        if (firstChunk) {
            // If this is the start of the content of this (gzipped) file, inject any
            // script-overriding code as necessary.
            if (incomingContentType == PROXY_CONTENT_HTML) {
                data = [self htmlDataWithJavascriptInjection:data];
            } else if (incomingContentType == PROXY_CONTENT_JS) {
                data = [self javascriptDataWithJavascriptInjection:data];
            }
            // Don't do this injection the next time around
            firstChunk = NO;
        }

        [self.client URLProtocol:self didLoadData:data];
    }
}

- (void)HTTPConnectionDidFinishLoading:(CKHTTPConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
    [self setConnection:nil];
    _data = nil;
}
- (void)HTTPConnection:(CKHTTPConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
	[self setConnection:nil];
	 _data = nil;
}



- (NSData *)htmlDataWithJavascriptInjection:incomingData {
    /* As used in "- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveData:(NSData *)data",
     * this takes the first chunk of raw HTML (ungizipped) and prepends a DOCTYPE and some
     * JS overrides before the page starts.
     *
     * Incredibly hacky, but allows us to catch any troublesome javascript methods before anybody's
     * script executes on-page. Currently allows rewriting `navigator.Useragent` but will eventually be
     * used to truly ensure that sockets & other dangerous JS-based dynamic content are blocked.
     */
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSMutableData *newData = [[NSMutableData alloc] init];

    // Prepend a DOCTYPE (to force into standards mode) and throw in any javascript overrides
    [newData appendData:[[NSString stringWithFormat:@"<!DOCTYPE html><script>%@</script>", appDelegate.javascriptInjection] dataUsingEncoding:NSUTF8StringEncoding]];
    [newData appendData:incomingData];
    return newData;
}

- (NSData *)javascriptDataWithJavascriptInjection:incomingData {
    /* As used in "- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveData:(NSData *)data",
     * this takes the first chunk of javascript (from a .js file included in a <script> tag and prepends
     * JS overrides before the rest of this script starts.
     *
     * Incredibly hacky, but allows us to catch any troublesome javascript methods before anybody's
     * script executes on-page. Currently allows rewriting `navigator.Useragent` but will eventually be
     * used to truly ensure that sockets & other dangerous JS-based dynamic content are blocked.
     */
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    NSMutableData *newData = [[NSMutableData alloc] init];

    [newData appendData:[[NSString stringWithFormat:@"%@\n", appDelegate.javascriptInjection] dataUsingEncoding:NSUTF8StringEncoding]];
    [newData appendData:incomingData];
    return newData;
}
@end
