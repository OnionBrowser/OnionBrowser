//
//  ProxyURLProtocol.m
//  PandoraBoy
//
//  Created by Rob Napier on 11/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

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

    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSMutableDictionary *settings = appDelegate.getSettings;

    // Modify request
    NSMutableURLRequest *myRequest = [request mutableCopy];
    
    [myRequest setHTTPShouldUsePipelining:[[settings valueForKey:@"pipelining"] integerValue]];
    
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
    if ( !([[[request URL] scheme] isEqualToString:@"file"] ||
           [[[request URL] scheme] isEqualToString:@"data"] ||
           [[[request URL] scheme] isEqualToString:@"itms"] ||
           [[[request URL] scheme] isEqualToString:@"itms-apps"]
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
    if ([[[[self request] URL] scheme] isEqualToString:@"onionbrowser"]) {
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
            url = [NSURL URLWithString: [NSString stringWithFormat:@"file:/%@/Icon@2x.png",resourcePath]];
        } else if ([[[[self request] URL] absoluteString] rangeOfString:@"help"].location != NSNotFound) {
            /* onionbrowser:help */
            url = [NSURL URLWithString: [NSString stringWithFormat:@"file:/%@/help.html",resourcePath]];
        } else if ([[[[self request] URL] absoluteString] rangeOfString:@"forcequit"].location != NSNotFound) {
            /* onionbrowser:forcequit */
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Force-quitting"
                                                            message:@"Onion Browser will now close. Restarting the app will try a fresh Tor connection."
                                                           delegate:self
                                                  cancelButtonTitle:@"Quit app"
                                                  otherButtonTitles:nil];
            [alert show];
        } else {
            /* onionbrowser:home */
            url = [NSURL URLWithString: [NSString stringWithFormat:@"file:/%@/startup.html",resourcePath]];
        }
        NSMutableURLRequest *newRequest = [NSMutableURLRequest requestWithURL:url];
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


- (void) alertView:(UIAlertView *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if ([actionSheet.title isEqualToString:@"Force-quitting"]) {
        AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
        [appDelegate wipeAppData];
        exit(0);
    }
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
        NSLog(@"[ProxyURLProtocol] Got response %d: content-type: %@", [response statusCode], [response MIMEType]);
    #endif
    if( _data != nil ) {
        _data = nil;
    }
    _data.length = 0;
    
    AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    NSMutableDictionary *settings = appDelegate.getSettings;

    /* If JAVASCRIPT_DISABLED setting is set, modify incoming headers to turn
     * on the "content-security-policy" and "x-webkit-csp" headers accordingly. */
    if ([[settings valueForKey:@"javascript"] integerValue] == JAVASCRIPT_DISABLED) {
        NSMutableDictionary *mHeaders = [NSMutableDictionary dictionary];
        for(id h in response.allHeaderFields) {
            if(![[h lowercaseString] isEqualToString:@"content-security-policy"] && ![[h lowercaseString] isEqualToString:@"x-webkit-csp"]) {
                // Delete existing content-security-policy headers (since we rely on writing our on strict ones)
                [mHeaders setObject:response.allHeaderFields[h] forKey:h];
            }
        }
        // http://www.html5rocks.com/en/tutorials/security/content-security-policy/#policy-applies-to-a-wide-variety-of-resources
        [mHeaders setObject:@"script-src 'none';media-src 'none';object-src 'none';connect-src 'none';font-src 'none';sandbox allow-forms;"
                     forKey:@"Content-Security-Policy"];
        [mHeaders setObject:@"script-src 'none';media-src 'none';object-src 'none';connect-src 'none';font-src 'none';sandbox allow-forms;"
                     forKey:@"X-Webkit-CSP"];
        response = [[NSHTTPURLResponse alloc]
                    initWithURL:response.URL statusCode:response.statusCode
                    HTTPVersion:@"1.1" headerFields:mHeaders];
    }
    /* End header modification */

    if ((response.statusCode == 301)||(response.statusCode == 302)||(response.statusCode == 307)) {
        NSString *newURL = [[response allHeaderFields] objectForKey:@"Location"];
        #ifdef DEBUG
            NSLog(@"[ProxyURLProtocol] Got %d redirect from %@ to %@", response.statusCode, _request.URL, newURL);
        #endif

        NSMutableURLRequest *newRequest = [_request mutableCopy];
        [newRequest setHTTPShouldUsePipelining:[[settings valueForKey:@"pipelining"] integerValue]];
        newRequest.URL = [NSURL URLWithString:newURL relativeToURL:_request.URL];
        _request = newRequest;
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
        if ([[[response URL] scheme] isEqualToString:@"http"] || [[[response URL] scheme] isEqualToString:@"https"]) {
            textResponse = [[NSHTTPURLResponse alloc] initWithURL:response.URL statusCode:response.statusCode HTTPVersion:@"1.1" headerFields:[response allHeaderFields]];
        } else {
            textResponse = [[NSURLResponse alloc] initWithURL:response.URL MIMEType:mime expectedContentLength:response.expectedContentLength textEncodingName:encoding];
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
            [self.client URLProtocol:self didLoadData:newData];
            _data = nil;
        }
    } else {
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



@end
