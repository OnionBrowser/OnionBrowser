//
//  ProxyURLProtocol.m
//  PandoraBoy
//
//  Created by Rob Napier on 11/30/07.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "ProxyURLProtocol.h"
#import <Foundation/NSURLProtocol.h>

static NSString *PBProxyURLHeader = @"X-PB";

@implementation ProxyURLProtocol

// Accessors

- (CKHTTPConnection *)connection {
    return [[_connection retain] autorelease];
}

- (void)setConnection:(CKHTTPConnection *)value {
    if (_connection != value) {
        [_connection release];
        _connection = [value retain];
    }
}

-(id)initWithRequest:(NSURLRequest *)request
      cachedResponse:(NSCachedURLResponse *)cachedResponse
              client:(id <NSURLProtocolClient>)client {
    // Modify request
    NSMutableURLRequest *myRequest = [request mutableCopy];
    [myRequest setValue:@"" forHTTPHeaderField:PBProxyURLHeader];
    [myRequest retain];
    
    self = [super initWithRequest:myRequest
                   cachedResponse:cachedResponse
                           client:client];
    if ( self ) {
        [self setRequest:myRequest];
    }
    return self;
}

- (NSURLRequest *)request {
    return [[_request retain] autorelease];
}

- (void)setRequest:(NSURLRequest *)value {
    if (_request != value) {
        [_request release];
        _request = [value retain];
    }
}

- (NSMutableData *)data {
    return [[_data retain] autorelease];
}

- (void)appendData:(NSData *)newData {
    if( _data == nil ) {
        _data = [[NSMutableData alloc] initWithData:newData];
    }
    else
    {
        [_data appendData:newData];
    }
}

// Class methods

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ( ([[[request URL] scheme] isEqualToString:@"http"] || [[[request URL] scheme] isEqualToString:@"https"]) &&
        [request valueForHTTPHeaderField:PBProxyURLHeader] == nil )
    {
        return YES;
    }
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)dealloc
{
    [_request release];
    [_connection release];
    [_data release];
    [super dealloc];
}

// Instance methods

- (void)startLoading {
    CKHTTPConnection *con = [CKHTTPConnection connectionWithRequest:[self request] delegate:self];
    [self setConnection:con];
}

-(void)stopLoading {
    [[self connection] cancel];
}

#pragma mark - 
#pragma mark NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
    [self appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
	[self setConnection:nil];
	[_data release]; _data = nil;
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    if( _data != nil ) {
        [_data release];
        _data = nil;
    }
    _data.length = 0;

    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];    
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
	[self setConnection:nil];
	[_data release]; _data = nil;
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
    #ifdef DEBUG
        NSLog(@"[ProxyURLProtocol] Got response: content-type: %@", [response MIMEType]);
    #endif
    if( _data != nil ) {
        [_data release];
        _data = nil;
    }
    _data.length = 0;
    
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
        NSArray *charset_bits = [content_type componentsSeparatedByString:@"charset="];
        if ([charset_bits count] > 1) {
            encoding = [charset_bits objectAtIndex:1];
        }
        #ifdef DEBUG
            NSLog(@"[ProxyURLProtocol] parsed content-type=%@, encoding=%@", mime, encoding);
        #endif
        NSURLResponse *textResponse = [[NSURLResponse alloc] initWithURL:response.URL MIMEType:mime expectedContentLength:response.expectedContentLength textEncodingName:encoding];
        [self.client URLProtocol:self didReceiveResponse:textResponse cacheStoragePolicy:NSURLCacheStorageAllowedInMemoryOnly];
    }
}
- (void)HTTPConnection:(CKHTTPConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
    [self appendData:data];
}

- (void)HTTPConnectionDidFinishLoading:(CKHTTPConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
	[self setConnection:nil];
	[_data release]; _data = nil;
}
- (void)HTTPConnection:(CKHTTPConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
	[self setConnection:nil];
	[_data release]; _data = nil;
}



@end
