/*
 * QRCodeReaderViewController
 *
 * Copyright 2014-present Yannick Loriot.
 * http://yannickloriot.com
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 */

#import <UIKit/UIKit.h>
#import "QRCodeReaderDelegate.h"
#import "QRCodeReader.h"

/**
 * Convenient controller to display a view to scan/read 1D or 2D bar codes like
 * the QRCodes. It is based on the `AVFoundation` framework from Apple. It aims 
 * to replace ZXing or ZBar for iOS 7 and over.
 */
@interface QRCodeReaderViewController : UIViewController

#pragma mark - Creating and Inializing QRCodeReader Controllers
/** @name Creating and Inializing QRCode Reader Controllers */

/**
 * @abstract Initializes a view controller to read QRCodes from a displayed 
 * video preview and a cancel button to be go back.
 * @param cancelTitle The title of the cancel button.
 * @discussion This convenient method is used to instanciate a reader with
 * only one supported metadata object types: the QRCode.
 * @see initWithCancelButtonTitle:metadataObjectTypes:
 * @since 1.0.0
 */
- (id)initWithCancelButtonTitle:(NSString *)cancelTitle;

/**
 * @abstract Creates a view controller to read QRCodes from a displayed
 * video preview and a cancel button to be go back.
 * @param cancelTitle The title of the cancel button.
 * @see initWithCancelButtonTitle:
 * @since 1.0.0
 */
+ (instancetype)readerWithCancelButtonTitle:(NSString *)cancelTitle;

/**
 * @abstract Initializes a reader view controller with a list of metadata 
 * object types.
 * @param metadataObjectTypes An array of strings identifying the types of
 * metadata objects to process.
 * @see initWithCancelButtonTitle:metadataObjectTypes:
 * @since 3.0.0
 */
- (id)initWithMetadataObjectTypes:(NSArray *)metadataObjectTypes;

/**
 * @abstract Creates a reader view controller with a list of metadata object
 * types.
 * @param metadataObjectTypes An array of strings identifying the types of
 * metadata objects to process.
 * @see initWithMetadataObjectTypes:
 * @since 3.0.0
 */
+ (instancetype)readerWithMetadataObjectTypes:(NSArray *)metadataObjectTypes;

/**
 * @abstract Initializes a view controller to read wanted metadata object
 * types from a displayed video preview and a cancel button to be go back.
 * @param cancelTitle The title of the cancel button.
 * @param metadataObjectTypes The type (“symbology”) of barcode to scan.
 * @see initWithCancelButtonTitle:codeReader:
 * @since 2.0.0
 */
- (id)initWithCancelButtonTitle:(NSString *)cancelTitle metadataObjectTypes:(NSArray *)metadataObjectTypes;

/**
 * @abstract Creates a view controller to read wanted metadata object types
 * from a displayed video preview and a cancel button to be go back.
 * @param cancelTitle The title of the cancel button.
 * @param metadataObjectTypes The type (“symbology”) of barcode to scan.
 * @see initWithCancelButtonTitle:metadataObjectTypes:
 * @since 2.0.0
 */
+ (instancetype)readerWithCancelButtonTitle:(NSString *)cancelTitle metadataObjectTypes:(NSArray *)metadataObjectTypes;

/**
 * @abstract Initializes a view controller using a cancel button title and
 * a code reader.
 * @param cancelTitle The title of the cancel button.
 * @param codeReader The reader to decode the codes.
 * @since 3.0.0
 */
- (id)initWithCancelButtonTitle:(NSString *)cancelTitle codeReader:(QRCodeReader *)codeReader;

/**
 * @abstract Initializes a view controller using a cancel button title and
 * a code reader.
 * @param cancelTitle The title of the cancel button.
 * @param codeReader The reader to decode the codes.
 * @see initWithCancelButtonTitle:codeReader:
 * @since 3.0.0
 */
+ (instancetype)readerWithCancelButtonTitle:(NSString *)cancelTitle codeReader:(QRCodeReader *)codeReader;

#pragma mark - Managing the Delegate
/** @name Managing the Delegate */

/**
 * @abstract The object that acts as the delegate of the receiving QRCode
 * reader.
 * @since 1.0.0
 */
@property (nonatomic, weak) id<QRCodeReaderDelegate> delegate;

/**
 * @abstract Sets the completion with a block that executes when a QRCode 
 * or when the user did stopped the scan.
 * @param completionBlock The block to be executed. This block has no 
 * return value and takes one argument: the `resultAsString`. If the user
 * stop the scan and that there is no response the `resultAsString` argument
 * is nil.
 * @since 1.0.1
 */
- (void)setCompletionWithBlock:(void (^) (NSString *resultAsString))completionBlock;

#pragma mark - Managing the Reader
/** @name Managing the Reader */

/**
 * @abstract The default code reader created with the controller.
 * @since 3.0.0
 */
@property (strong, nonatomic, readonly) QRCodeReader *codeReader;

@end
