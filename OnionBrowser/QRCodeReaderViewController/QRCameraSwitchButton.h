// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// This file is derived from QRCodeReaderViewController, under the MIT License.
// Copyright (c) 2014-present Yannick Loriot

#import <UIKit/UIKit.h>

/**
 * The camera switch button.
 * @since 2.0.0
 */
@interface QRCameraSwitchButton : UIButton

#pragma mark - Managing Properties
/** @name Managing Properties */

/**
 * @abstract The edge color of the drawing.
 * @discussion The default color is the white.
 * @since 2.0.0
 */
@property (nonatomic, strong) UIColor *edgeColor;

/**
 * @abstract The fill color of the drawing.
 * @discussion The default color is the darkgray.
 * @since 2.0.0
 */
@property (nonatomic, strong) UIColor *fillColor;

/**
 * @abstract The edge color of the drawing when the button is touched.
 * @discussion The default color is the white.
 * @since 2.0.0
 */
@property (nonatomic, strong) UIColor *edgeHighlightedColor;

/**
 * @abstract The fill color of the drawing when the button is touched.
 * @discussion The default color is the black.
 * @since 2.0.0
 */
@property (nonatomic, strong) UIColor *fillHighlightedColor;

@end
