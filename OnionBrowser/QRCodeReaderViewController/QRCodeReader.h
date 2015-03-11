/*
 * QRCodeReader
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

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

/**
 * Reader object base on the `AVCaptureDevice` to read / scan 1D and 2D codes.
 */
@interface QRCodeReader : NSObject

#pragma mark - Creating and Inializing QRCode Readers
/** @name Creating and Inializing QRCode Readers */

/**
 * @abstract Initializes a reader with a list of metadata object types.
 * @param metadataObjectTypes An array of strings identifying the types of
 * metadata objects to process.
 * @since 3.0.0
 */
- (id)initWithMetadataObjectTypes:(NSArray *)metadataObjectTypes;

/**
 * @abstract Creates a reader with a list of metadata object types.
 * @param metadataObjectTypes An array of strings identifying the types of
 * metadata objects to process.
 * @see initWithMetadataObjectTypes:
 * @since 3.0.0
 */
+ (instancetype)readerWithMetadataObjectTypes:(NSArray *)metadataObjectTypes;

#pragma mark - Checking the Reader Availabilities
/** @name Checking the Reader Availabilities */

/**
 * @abstract Returns whether the reader is available with the current device.
 * @return a Boolean value indicating whether the reader is available.
 * @since 3.0.0
 */
+ (BOOL)isAvailable;

/**
 * @abstract Checks and return whether the given metadata object types are
 * supported by the current device.
 * @return a Boolean value indicating whether the given metadata object types
 * are supported by the current device.
 * @since 3.2.0
 */
+ (BOOL)supportsMetadataObjectTypes:(NSArray *)metadataObjectTypes;

#pragma mark - Checking the Metadata Items Types
/** @name Checking the Metadata Items Types */

/**
 * @abstract An array of strings identifying the types of metadata objects to
 * process.
 * @since 3.0.0
 */
@property (strong, nonatomic, readonly) NSArray *metadataObjectTypes;

#pragma mark - Viewing the Camera
/** @name Viewing the Camera */

/**
 * @abstract CALayer that you use to display video as it is being captured
 * by an input device.
 * @since 3.0.0
 */
@property (strong, nonatomic, readonly) AVCaptureVideoPreviewLayer *previewLayer;

#pragma mark - Controlling the Reader
/** @name Controlling the Reader */

/**
 * @abstract Starts scanning the codes.
 * @since 3.0.0
 */
- (void)startScanning;

/**
 * @abstract Stops scanning the codes.
 * @since 3.0.0
 */
- (void)stopScanning;

/**
 * @abstract Switch between the back and the front camera.
 * @since 3.0.0
 */
- (void)switchDeviceInput;

/**
 * @abstract Returns true whether a front device is available.
 * @return true whether a front device is available.
 * @since 3.0.0
 */
- (BOOL)hasFrontDevice;

#pragma mark - Managing the Orientation
/** @name Managing the Orientation */

/**
 * @abstract Returns the video orientation correspongind to the given interface
 * orientation.
 * @param interfaceOrientation An interface orientation.
 * @return the video orientation correspongind to the given device orientation.
 * @since 3.1.0
 */
+ (AVCaptureVideoOrientation)videoOrientationFromInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation;


#pragma mark - Managing the Block
/** @name Managing the Block */

/**
 * @abstract Sets the completion with a block that executes when a QRCode
 * or when the user did stopped the scan.
 * @param completionBlock The block to be executed. This block has no
 * return value and takes one argument: the `resultAsString`. If the user
 * stop the scan and that there is no response the `resultAsString` argument
 * is nil.
 * @since 3.0.0
 */
- (void)setCompletionWithBlock:(void (^) (NSString *resultAsString))completionBlock;

@end
