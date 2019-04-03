//
//  WebViewTab+Activity.h
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 03.04.19.
//  Copyright © 2019 jcs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebViewTab.h"

NS_ASSUME_NONNULL_BEGIN

@interface WebViewTab (Activity) <UIActivityItemSource>

/**
 The UTI evaluated from contentType.
 */
@property (nonatomic, readonly) CFStringRef uti;

/**
 Document at UIWebView's url is an document like a PDF or DOC or plain-text,
 or an image or video, BUT NOT markup (HTML and XML).
 */
@property (nonatomic, readonly) BOOL isDocument;

/**
 Document at UIWebView's url is a text document like plain-text, RTF or even
 markup.
 */
@property (nonatomic, readonly) BOOL isText;

/**
 Document at UIWebView's url is an image, audio or video.
 */
@property (nonatomic, readonly) BOOL isImageOrAv;

/**
 Document at UIWebView's url is a HTML or XML.
 */
@property (nonatomic, readonly) BOOL isMarkup;

/**
 The raw data from document itself.
 */
@property (nonatomic) NSData *content;

@property (nonatomic) BOOL downloadStarted;

@end

NS_ASSUME_NONNULL_END
