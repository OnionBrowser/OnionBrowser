//
//  WebViewTab+Activity.m
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 03.04.19.
//  Copyright © 2019 Guardian Project. All rights reserved.
//

#import "WebViewTab+Activity.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import <objc/runtime.h>

/**
 Tries to offer the currently open page in the most usable way to the user:

 - Images and audio/video will be offered as such and the user has the possibility
 to save to their camera roll.

 - Documents, like PDF, will be offered as NSData. The user will have the opportunity
 to save it to their iCloud drive or similar apps.

 - Markup will be offered as URLs.
 */
@implementation WebViewTab (Activity)

- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
	if (self.downloadedFile)
	{
		if (self.isImageOrAv)
		{
			return [[UIImage alloc] init];
		}

		if (self.isDocument)
		{
			return [[NSData alloc] init];
		}
	}

	return self.url;
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(UIActivityType)activityType
{
	NSLog(@"[%@] activityType=%@", self.class, activityType);

	if (self.downloadedFile) {
		if (activityType == UIActivityTypePrint
			|| activityType == UIActivityTypeMarkupAsPDF
			|| activityType == UIActivityTypeMail
			|| activityType == UIActivityTypeOpenInIBooks
			|| activityType == UIActivityTypeAirDrop
			|| activityType == UIActivityTypeCopyToPasteboard
			|| activityType == UIActivityTypeSaveToCameraRoll
			|| [activityType isEqualToString:@"com.apple.CloudDocsUI.AddToiCloudDrive"]) {

			// Return local file URL -> The file will be loaded and shared from there
			// and it will use the correct file name.
			return self.downloadedFile;
		}

		if (activityType == UIActivityTypeMessage) {
			if (self.isImageOrAv) {
				return self.downloadedFile;
			}
		}
	}

	return self.url;
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(UIActivityType)activityType
{
	return self.title.text;
}

- (NSString *)activityViewController:(UIActivityViewController *)activityViewController dataTypeIdentifierForActivityType:(UIActivityType)activityType
{
	NSString *uti = self.uti;

	if (uti)
	{
		return uti;
	}

	return (__bridge NSString *)kUTTypeURL;
}

- (nullable UIImage *)activityViewController:(UIActivityViewController *)activityViewController
			   thumbnailImageForActivityType:(nullable UIActivityType)activityType
							   suggestedSize:(CGSize)size
{
	UIGraphicsBeginImageContext(size);

	if (self.downloadedFile)
	{
		[self.previewController.view.layer renderInContext:UIGraphicsGetCurrentContext()];
	}
	else {
		[self.webView.layer renderInContext:UIGraphicsGetCurrentContext()];
	}

	UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

	return thumbnail;
}

- (NSString *)uti
{
	NSString *uti = nil;

	if (self.downloadedFile)
	{
		uti = [self.downloadedFile resourceValuesForKeys:@[NSURLTypeIdentifierKey] error:nil][NSURLTypeIdentifierKey];
	}

	return uti;
}

- (BOOL)isImageOrAv
{
	CFStringRef uti = (__bridge CFStringRef)self.uti;

	Boolean isImageOrAv = UTTypeConformsTo(uti, kUTTypeImage)
		|| UTTypeConformsTo(uti, kUTTypeAudiovisualContent);

	return !!isImageOrAv;
}

- (BOOL)isDocument
{
	CFStringRef uti = (__bridge CFStringRef)self.uti;

	Boolean isDocument = UTTypeConformsTo(uti, kUTTypeData)
		&& !UTTypeConformsTo(uti, kUTTypeHTML)
		&& !UTTypeConformsTo(uti, kUTTypeXML);

	return !!isDocument;
}


@end
