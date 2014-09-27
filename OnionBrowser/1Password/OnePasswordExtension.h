//
//  1Password App Extension
//
//  Lovingly handcrafted by Dave Teare, Michael Fey, Rad Azzouz, and Roustem Karimov.
//  Copyright (c) 2014 AgileBits. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

#ifdef __IPHONE_8_0
#import <WebKit/WebKit.h>
#endif

// Login Dictionary keys
FOUNDATION_EXPORT NSString *const AppExtensionURLStringKey;
FOUNDATION_EXPORT NSString *const AppExtensionUsernameKey;
FOUNDATION_EXPORT NSString *const AppExtensionPasswordKey;
FOUNDATION_EXPORT NSString *const AppExtensionTitleKey;
FOUNDATION_EXPORT NSString *const AppExtensionNotesKey;
FOUNDATION_EXPORT NSString *const AppExtensionSectionTitleKey;
FOUNDATION_EXPORT NSString *const AppExtensionFieldsKey;
FOUNDATION_EXPORT NSString *const AppExtensionReturnedFieldsKey;
FOUNDATION_EXPORT NSString *const AppExtensionOldPasswordKey;
FOUNDATION_EXPORT NSString *const AppExtensionPasswordGereratorOptionsKey;

// Password Generator options
FOUNDATION_EXPORT NSString *const AppExtensionGeneratedPasswordMinLengthKey;
FOUNDATION_EXPORT NSString *const AppExtensionGeneratedPasswordMaxLengthKey;

// Errors
FOUNDATION_EXPORT NSString *const AppExtensionErrorDomain;
FOUNDATION_EXPORT NSInteger const AppExtensionErrorCodeCancelledByUser;

FOUNDATION_EXPORT NSInteger const AppExtensionErrorCodeAPINotAvailable;
FOUNDATION_EXPORT NSInteger const AppExtensionErrorCodeFailedToContactExtension;
FOUNDATION_EXPORT NSInteger const AppExtensionErrorCodeFailedToLoadItemProviderData;
FOUNDATION_EXPORT NSInteger const AppExtensionErrorCodeCollectFieldsScriptFailed;
FOUNDATION_EXPORT NSInteger const AppExtensionErrorCodeFillFieldsScriptFailed;
FOUNDATION_EXPORT NSInteger const AppExtensionErrorCodeUnexpectedData;

@interface OnePasswordExtension : NSObject

+ (OnePasswordExtension *)sharedExtension;

/*!
 Determines if the 1Password App Extension is available. Allows you to only show the 1Password login button to those
 that can use it. Of course, you could leave the button enabled and educate users about the virtues of strong, unique 
 passwords instead :)
 
 Note that this returns YES if any app that supports the generic `org-appextension-feature-password-management` feature 
 is installed.
 */
#ifdef __IPHONE_8_0
- (BOOL)isAppExtensionAvailable NS_EXTENSION_UNAVAILABLE_IOS("Not available in an extension. Check if org-appextension-feature-password-management:// URL can be opened by the app.");
#else
- (BOOL)isAppExtensionAvailable;
#endif

/*!
 Called from your login page, this method will find all available logins for the given URLString. After the user selects 
 a login, it is stored into an NSDictionary and given to your completion handler. Use the `Login Dictionary keys` above to 
 extract the needed information and update your UI. The completion block is guaranteed to be called on the main thread.
 */
- (void)findLoginForURLString:(NSString *)URLString forViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(NSDictionary *loginDict, NSError *error))completion;

/*!
 Create a new login within 1Password and allow the user to generate a new password before saving. The provided URLString should be 
 unique to your app or service and be identical to what you pass into the find login method.
 
 Details about the saved login, including the generated password, are stored in an NSDictionary and given to your completion handler. 
 Use the `Login Dictionary keys` above to extract the needed information and update your UI. For example, updating the UI with the 
 newly generated password lets the user know their action was successful. The completion block is guaranteed to be called on the main
 thread.
 */
- (void)storeLoginForURLString:(NSString *)URLString loginDetails:(NSDictionary *)loginDetailsDict passwordGenerationOptions:(NSDictionary *)passwordGenerationOptions forViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(NSDictionary *loginDict, NSError *error))completion;

/*!
 Change the password for an existing login within 1Password. The provided URLString should be
 unique to your app or service and be identical to what you pass into the find login method. The username must be the one that the user is currently logged in with.

 Details about the saved login, including the newly generated and the old password, are stored in an NSDictionary and given to your completion handler.
 Use the `Login Dictionary keys` above to extract the needed information and update your UI. For example, updating the UI with the
 newly generated password lets the user know their action was successful. The completion block is guaranteed to be called on the main
 thread.
 */
- (void)changePasswordForLoginForURLString:(NSString *)URLString loginDetails:(NSDictionary *)loginDetailsDict passwordGenerationOptions:(NSDictionary *)passwordGenerationOptions forViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(NSDictionary *loginDict, NSError *error))completion;

/*!
 Called from your web view controller, this method will show all the saved logins for the active page in the provided web
 view, and automatically fill the HTML form fields. Supports both WKWebView and UIWebView.
 */
- (void)fillLoginIntoWebView:(id)webView forViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(BOOL success, NSError *error))completion;

@end
