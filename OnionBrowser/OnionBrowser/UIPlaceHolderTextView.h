//
//  UIPlaceHolderTextView.h
//  OnionBrowser
//
//  Created by Mike Tigas on 3/10/15.
//
//

#import <UIKit/UIKit.h>

@interface UIPlaceHolderTextView : UITextView

@property (nonatomic, retain) NSString *placeholder;
@property (nonatomic, retain) UIColor *placeholderColor;

-(void)textChanged:(NSNotification*)notification;

@end
