//
//  TorProxyURLProtocol.m
//
//  Onion Browser fork by Mike Tigas
//  Copyright 2012-2016 Mike Tigas. All rights reserved.
//  https://github.com/OnionBrowser/iOS-OnionBrowser/blob/master/LICENSE
//
//  Created by Rob Napier on 11/30/07.
//  Copyright 2007. All rights reserved.

#import "TorProxyURLProtocol.h"
#import <Foundation/NSURLProtocol.h>
#import "NSData+CocoaDevUsersAdditions.h"


@implementation TorProxyURLProtocol

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
    //#ifdef DEBUG
    //    NSLog(@"[ProxyURLProtocol] Got response %ld: content-type: %@", (long)[response statusCode], [response MIMEType]);
    //#endif
    if( _data != nil ) {
        _data = nil;
    }
    _data.length = 0;

    /* Handle redirects */
    if ((response.statusCode == 301)||(response.statusCode == 302)||(response.statusCode == 307)) {
        NSString *newURL = [[response allHeaderFields] objectForKey:@"Location"];
        //#ifdef DEBUG
        //    NSLog(@"[ProxyURLProtocol] Got %ld redirect from %@ to %@", (long)response.statusCode, _request.URL, newURL);
        //#endif

        NSMutableURLRequest *newRequest = [_request mutableCopy];
        [newRequest setHTTPShouldUsePipelining:YES];
        newRequest.URL = [NSURL URLWithString:newURL relativeToURL:_request.URL];
        if ([[_request mainDocumentURL] isEqual:[_request URL]]) {
          // Previous request *was* the maindocument request.
          newRequest.mainDocumentURL = newRequest.URL;
        }

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
        //#ifdef DEBUG
        //    NSLog(@"[ProxyURLProtocol] parsed content-type=%@, encoding=%@, content_encoding=%@", mime, encoding, content_encoding);
        //#endif
        NSURLResponse *textResponse;
        if ([[[[response URL] scheme] lowercaseString] isEqualToString:@"http"] || [[[[response URL] scheme] lowercaseString] isEqualToString:@"https"]) {
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
