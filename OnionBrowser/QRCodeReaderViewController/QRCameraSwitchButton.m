// This file is part of Onion Browser 1.7 - https://mike.tig.as/onionbrowser/
// Copyright © 2012-2016 Mike Tigas
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// This file is derived from QRCodeReaderViewController, under the MIT License.
// Copyright (c) 2014-present Yannick Loriot

#import "QRCameraSwitchButton.h"

@implementation QRCameraSwitchButton

- (id)initWithFrame:(CGRect)frame
{
  if ((self = [super initWithFrame:frame])) {
    _edgeColor            = [UIColor whiteColor];
    _fillColor            = [UIColor darkGrayColor];
    _edgeHighlightedColor = [UIColor whiteColor];
    _fillHighlightedColor = [UIColor blackColor];
  }
  return self;
}

- (void)drawRect:(CGRect)rect
{
  CGFloat width  = rect.size.width;
  CGFloat height = rect.size.height;
  CGFloat center = width / 2;
  CGFloat middle = height / 2;

  CGFloat strokeLineWidth = 2;

  // Colors

  UIColor *paintColor  = (self.state != UIControlStateHighlighted) ? _fillColor : _fillHighlightedColor;
  UIColor *strokeColor = (self.state != UIControlStateHighlighted) ? _edgeColor : _edgeHighlightedColor;

  // Camera box

  CGFloat cameraWidth  = width * 0.4;
  CGFloat cameraHeight = cameraWidth * 0.6;
  CGFloat cameraX      = center - cameraWidth / 2;
  CGFloat cameraY      = middle - cameraHeight / 2;
  CGFloat cameraRadius = cameraWidth / 80;

  UIBezierPath *boxPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(cameraX, cameraY, cameraWidth, cameraHeight) cornerRadius:cameraRadius];

  // Camera lens

  CGFloat outerLensSize = cameraHeight * 0.8;
  CGFloat outerLensX    = center - outerLensSize / 2;
  CGFloat outerLensY    = middle - outerLensSize / 2;

  CGFloat innerLensSize = outerLensSize * 0.7;
  CGFloat innerLensX    = center - innerLensSize / 2;
  CGFloat innerLensY    = middle - innerLensSize / 2;

  UIBezierPath *outerLensPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(outerLensX, outerLensY, outerLensSize, outerLensSize)];
  UIBezierPath *innerLensPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(innerLensX, innerLensY, innerLensSize, innerLensSize)];

  // Draw flash box

  CGFloat flashBoxWidth      = cameraWidth * 0.8;
  CGFloat flashBoxHeight     = cameraHeight * 0.17;
  CGFloat flashBoxDeltaWidth = flashBoxWidth * 0.14;
  CGFloat flashLeftMostX     = cameraX + (cameraWidth - flashBoxWidth) * 0.5;
  CGFloat flashBottomMostY   = cameraY;

  UIBezierPath *flashPath = [UIBezierPath bezierPath];
  [flashPath moveToPoint:CGPointMake(flashLeftMostX, flashBottomMostY)];
  [flashPath addLineToPoint:CGPointMake(flashLeftMostX + flashBoxWidth, flashBottomMostY)];
  [flashPath addLineToPoint:CGPointMake(flashLeftMostX + flashBoxWidth - flashBoxDeltaWidth, flashBottomMostY - flashBoxHeight)];
  [flashPath addLineToPoint:CGPointMake(flashLeftMostX + flashBoxDeltaWidth, flashBottomMostY - flashBoxHeight)];
  [flashPath closePath];

  flashPath.lineCapStyle = kCGLineCapRound;
  flashPath.lineJoinStyle = kCGLineJoinRound;

  // Arrows

  CGFloat arrowHeadHeigth = cameraHeight * 0.5;
  CGFloat arrowHeadWidth  = ((width - cameraWidth) / 2) * 0.3;
  CGFloat arrowTailHeigth = arrowHeadHeigth * 0.6;
  CGFloat arrowTailWidth  = ((width - cameraWidth) / 2) * 0.7;

  // Draw left arrow

  CGFloat arrowLeftX = center - cameraWidth * 0.2;
  CGFloat arrowLeftY = middle + cameraHeight * 0.45;

  UIBezierPath *leftArrowPath = [UIBezierPath bezierPath];
  [leftArrowPath moveToPoint:CGPointMake(arrowLeftX, arrowLeftY)];
  [leftArrowPath addLineToPoint:CGPointMake(arrowLeftX - arrowHeadWidth, arrowLeftY - arrowHeadHeigth / 2)];
  [leftArrowPath addLineToPoint:CGPointMake(arrowLeftX - arrowHeadWidth, arrowLeftY - arrowTailHeigth / 2)];
  [leftArrowPath addLineToPoint:CGPointMake(arrowLeftX - arrowHeadWidth - arrowTailWidth, arrowLeftY - arrowTailHeigth / 2)];
  [leftArrowPath addLineToPoint:CGPointMake(arrowLeftX - arrowHeadWidth - arrowTailWidth, arrowLeftY + arrowTailHeigth / 2)];
  [leftArrowPath addLineToPoint:CGPointMake(arrowLeftX - arrowHeadWidth, arrowLeftY + arrowTailHeigth / 2)];
  [leftArrowPath addLineToPoint:CGPointMake(arrowLeftX - arrowHeadWidth, arrowLeftY + arrowHeadHeigth / 2)];
  [leftArrowPath closePath];

  // Right arrow

  CGFloat arrowRightX = center + cameraWidth * 0.2;
  CGFloat arrowRightY = middle + cameraHeight * 0.60;

  UIBezierPath *rigthArrowPath = [UIBezierPath bezierPath];
  [rigthArrowPath moveToPoint:CGPointMake(arrowRightX, arrowRightY)];
  [rigthArrowPath addLineToPoint:CGPointMake(arrowRightX + arrowHeadWidth, arrowRightY - arrowHeadHeigth / 2)];
  [rigthArrowPath addLineToPoint:CGPointMake(arrowRightX + arrowHeadWidth, arrowRightY - arrowTailHeigth / 2)];
  [rigthArrowPath addLineToPoint:CGPointMake(arrowRightX + arrowHeadWidth + arrowTailWidth, arrowRightY - arrowTailHeigth / 2)];
  [rigthArrowPath addLineToPoint:CGPointMake(arrowRightX + arrowHeadWidth + arrowTailWidth, arrowRightY + arrowTailHeigth / 2)];
  [rigthArrowPath addLineToPoint:CGPointMake(arrowRightX + arrowHeadWidth, arrowRightY + arrowTailHeigth / 2)];
  [rigthArrowPath addLineToPoint:CGPointMake(arrowRightX + arrowHeadWidth, arrowRightY + arrowHeadHeigth / 2)];
  [rigthArrowPath closePath];

  // Drawing

  [paintColor setFill];
  [rigthArrowPath fill];
  [strokeColor setStroke];
  rigthArrowPath.lineWidth = strokeLineWidth;
  [rigthArrowPath stroke];

  [paintColor setFill];
  [boxPath fill];
  [strokeColor setStroke];
  boxPath.lineWidth = strokeLineWidth;
  [boxPath stroke];

  [strokeColor setFill];
  [outerLensPath fill];

  [paintColor setFill];
  [innerLensPath fill];

  [paintColor setFill];
  [flashPath fill];
  [strokeColor setStroke];
  flashPath.lineWidth = strokeLineWidth;
  [flashPath stroke];

  [paintColor setFill];
  [leftArrowPath fill];
  [strokeColor setStroke];
  leftArrowPath.lineWidth = strokeLineWidth;
  [leftArrowPath stroke];
}

// MARK: - UIResponder Methods

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesBegan:touches withEvent:event];

  [self setNeedsDisplay];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesMoved:touches withEvent:event];

  [self setNeedsDisplay];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesEnded:touches withEvent:event];

  [self setNeedsDisplay];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
  [super touchesCancelled:touches withEvent:event];

  [self setNeedsDisplay];
}

@end
