//
//  WebViewTab+Activity.h
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 03.04.19.
//  Copyright © 2019 Guardian Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebViewTab.h"

NS_ASSUME_NONNULL_BEGIN

@interface WebViewTab (Activity) <UIActivityItemSource>

/**
 The UTI evaluated from contentType.
 */
@property (nonatomic, readonly) NSString *uti;

/**
 Check, if given UTI is a document like a PDF or DOC or plain-text,
 or an image or video, BUT NOT markup (HTML and XML).
 */
@property (nonatomic, readonly) BOOL isDocument;

/**
 Check, if given UTI is an image, audio or video.
 */
@property (nonatomic, readonly) BOOL isImageOrAv;

@end

NS_ASSUME_NONNULL_END
