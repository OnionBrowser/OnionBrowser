//
//  1Password App Extension
//
//  Lovingly handcrafted by Dave Teare, Michael Fey, Rad Azzouz, and Roustem Karimov.
//  Copyright (c) 2014 AgileBits. All rights reserved.
//

#import "OnePasswordExtension.h"

// Version
#define VERSION_NUMBER @(108)
NSString *const AppExtensionVersionNumberKey = @"version_number";

// Available App Extension Actions
NSString *const kUTTypeAppExtensionFindLoginAction = @"org.appextension.find-login-action";
NSString *const kUTTypeAppExtensionSaveLoginAction = @"org.appextension.save-login-action";
NSString *const kUTTypeAppExtensionChangePasswordAction = @"org.appextension.change-password-action";
NSString *const kUTTypeAppExtensionFillWebViewAction = @"org.appextension.fill-webview-action";

// Login Dictionary keys
NSString *const AppExtensionURLStringKey = @"url_string";
NSString *const AppExtensionUsernameKey = @"username";
NSString *const AppExtensionPasswordKey = @"password";
NSString *const AppExtensionTitleKey = @"login_title";
NSString *const AppExtensionNotesKey = @"notes";
NSString *const AppExtensionSectionTitleKey = @"section_title";
NSString *const AppExtensionFieldsKey = @"fields";
NSString *const AppExtensionReturnedFieldsKey = @"returned_fields";
NSString *const AppExtensionOldPasswordKey = @"old_password";
NSString *const AppExtensionPasswordGereratorOptionsKey = @"password_generator_options";

// WebView Dictionary keys
NSString *const AppExtensionWebViewPageFillScript = @"fillScript";
NSString *const AppExtensionWebViewPageDetails = @"pageDetails";

// Password Generator options
NSString *const AppExtensionGeneratedPasswordMinLengthKey = @"password_min_length";
NSString *const AppExtensionGeneratedPasswordMaxLengthKey = @"password_max_length";

// Errors
NSString *const AppExtensionErrorDomain = @"OnePasswordExtension";
NSInteger const AppExtensionErrorCodeCancelledByUser = 0;
NSInteger const AppExtensionErrorCodeAPINotAvailable = 1;
NSInteger const AppExtensionErrorCodeFailedToContactExtension = 2;
NSInteger const AppExtensionErrorCodeFailedToLoadItemProviderData = 3;
NSInteger const AppExtensionErrorCodeCollectFieldsScriptFailed = 4;
NSInteger const AppExtensionErrorCodeFillFieldsScriptFailed = 5;
NSInteger const AppExtensionErrorCodeUnexpectedData = 6;


@implementation OnePasswordExtension

#pragma mark - Public Methods

+ (OnePasswordExtension *)sharedExtension {
	static dispatch_once_t onceToken;
	static OnePasswordExtension *__sharedExtension;

	dispatch_once(&onceToken, ^{
		__sharedExtension = [OnePasswordExtension new];
	});
	
	return __sharedExtension;
}

- (BOOL)isSystemAppExtensionAPIAvailable {
#ifdef __IPHONE_8_0
	return NSClassFromString(@"NSExtensionItem") != nil;
#else
	return NO;
#endif
}

- (BOOL)isAppExtensionAvailable {
	if ([self isSystemAppExtensionAPIAvailable]) {
		return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"org-appextension-feature-password-management://"]];
    }

	return NO;
}

- (void)findLoginForURLString:(NSString *)URLString forViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(NSDictionary *loginDictionary, NSError *error))completion
{
	NSAssert(URLString != nil, @"URLString must not be nil");
	NSAssert(viewController != nil, @"viewController must not be nil");

	if (![self isSystemAppExtensionAPIAvailable]) {
		NSLog(@"Failed to findLoginForURLString, system API is not available");
		if (completion) {
			completion(nil, [OnePasswordExtension systemAppExtensionAPINotAvailableError]);
		}

		return;
	}

#ifdef __IPHONE_8_0
	NSDictionary *item = @{ AppExtensionVersionNumberKey: VERSION_NUMBER, AppExtensionURLStringKey: URLString };

	__weak typeof (self) miniMe = self;

	UIActivityViewController *activityViewController = [self activityViewControllerForItem:item viewController:viewController sender:sender typeIdentifier:kUTTypeAppExtensionFindLoginAction];
	activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
		if (returnedItems.count == 0) {
			NSError *error = nil;
			if (activityError) {
				NSLog(@"Failed to findLoginForURLString: %@", activityError);
				error = [OnePasswordExtension failedToContactExtensionErrorWithActivityError:activityError];
			}
			else {
				error = [OnePasswordExtension extensionCancelledByUserError];
			}

			if (completion) {
				completion(nil, error);
			}

			return;
		}

		__strong typeof(self) strongMe = miniMe;
		[strongMe processExtensionItem:returnedItems[0] completion:^(NSDictionary *loginDictionary, NSError *error) {
			if (completion) {
				completion(loginDictionary, error);
			}
		}];
	};
	
	[viewController presentViewController:activityViewController animated:YES completion:nil];
#endif
}

- (void)storeLoginForURLString:(NSString *)URLString loginDetails:(NSDictionary *)loginDetailsDict passwordGenerationOptions:(NSDictionary *)passwordGenerationOptions forViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(NSDictionary *, NSError *))completion;
{
	NSAssert(URLString != nil, @"URLString must not be nil");
	NSAssert(loginDetailsDict != nil, @"loginDetailsDict must not be nil");
	NSAssert(viewController != nil, @"viewController must not be nil");

	if (![self isSystemAppExtensionAPIAvailable]) {
		NSLog(@"Failed to storeLoginForURLString, system API is not available");
		if (completion) {
			completion(nil, [OnePasswordExtension systemAppExtensionAPINotAvailableError]);
		}

		return;
	}
	

#ifdef __IPHONE_8_0
	NSMutableDictionary *newLoginAttributesDict = [NSMutableDictionary new];
	newLoginAttributesDict[AppExtensionVersionNumberKey] = VERSION_NUMBER;
	newLoginAttributesDict[AppExtensionURLStringKey] = URLString;
	[newLoginAttributesDict addEntriesFromDictionary:loginDetailsDict];
	if (passwordGenerationOptions.count > 0) {
		newLoginAttributesDict[AppExtensionPasswordGereratorOptionsKey] = passwordGenerationOptions;
	}

	__weak typeof (self) miniMe = self;

	UIActivityViewController *activityViewController = [self activityViewControllerForItem:newLoginAttributesDict viewController:viewController sender:sender typeIdentifier:kUTTypeAppExtensionSaveLoginAction];
	activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
		if (returnedItems.count == 0) {
			NSError *error = nil;
			if (activityError) {
				NSLog(@"Failed to storeLoginForURLString: %@", activityError);
				error = [OnePasswordExtension failedToContactExtensionErrorWithActivityError:activityError];
			}
			else {
				error = [OnePasswordExtension extensionCancelledByUserError];
			}

			if (completion) {
				completion(nil, error);
			}

			return;
		}
		
		__strong typeof(self) strongMe = miniMe;
		[strongMe processExtensionItem:returnedItems[0] completion:^(NSDictionary *loginDictionary, NSError *error) {
			if (completion) {
				completion(loginDictionary, error);
			}
		}];
	};
	
	[viewController presentViewController:activityViewController animated:YES completion:nil];
#endif
}

- (void)changePasswordForLoginForURLString:(NSString *)URLString loginDetails:(NSDictionary *)loginDetailsDict passwordGenerationOptions:(NSDictionary *)passwordGenerationOptions forViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(NSDictionary *loginDict, NSError *error))completion
{
	NSAssert(URLString != nil, @"URLString must not be nil");
	NSAssert(viewController != nil, @"viewController must not be nil");

	if (![self isSystemAppExtensionAPIAvailable]) {
		NSLog(@"Failed to changePasswordForLoginWithUsername, system API is not available");
		if (completion) {
			completion(nil, [OnePasswordExtension systemAppExtensionAPINotAvailableError]);
		}

		return;
	}

#ifdef __IPHONE_8_0
	NSMutableDictionary *item = [NSMutableDictionary new];
	item[AppExtensionVersionNumberKey] = VERSION_NUMBER;
	item[AppExtensionURLStringKey] = URLString;
	[item addEntriesFromDictionary:loginDetailsDict];
	if (passwordGenerationOptions.count > 0) {
		item[AppExtensionPasswordGereratorOptionsKey] = passwordGenerationOptions;
	}

	__weak typeof (self) miniMe = self;
	UIActivityViewController *activityViewController = [self activityViewControllerForItem:item viewController:viewController sender:sender typeIdentifier:kUTTypeAppExtensionChangePasswordAction];

	activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
		if (returnedItems.count == 0) {
			NSError *error = nil;
			if (activityError) {
				NSLog(@"Failed to changePasswordForLoginWithUsername: %@", activityError);
				error = [OnePasswordExtension failedToContactExtensionErrorWithActivityError:activityError];
			}
			else {
				error = [OnePasswordExtension extensionCancelledByUserError];
			}

			if (completion) {
				completion(nil, error);
			}

			return;
		}

		__strong typeof(self) strongMe = miniMe;
		[strongMe processExtensionItem:returnedItems[0] completion:^(NSDictionary *loginDictionary, NSError *error) {
			if (completion) {
				completion(loginDictionary, error);
			}
		}];
	};

	[viewController presentViewController:activityViewController animated:YES completion:nil];
#endif
}

- (void)fillLoginIntoWebView:(id)webView forViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(BOOL success, NSError *error))completion
{
	NSAssert(webView != nil, @"webView must not be nil");
	NSAssert(viewController != nil, @"viewController must not be nil");

#ifdef __IPHONE_8_0
	if ([webView isKindOfClass:[UIWebView class]]) {
		[self fillLoginIntoUIWebView:webView webViewController:viewController sender:(id)sender completion:^(BOOL success, NSError *error) {
			if (completion) {
				completion(success, error);
			}
		}];
	}
#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
	else if ([webView isKindOfClass:[WKWebView class]]) {
		[self fillLoginIntoWKWebView:webView forViewController:viewController sender:(id)sender completion:^(BOOL success, NSError *error) {
			if (completion) {
				completion(success, error);
			}
		}];
	}
#endif
	else {
		[NSException raise:@"Invalid argument: web view must be an instance of WKWebView or UIWebView." format:@""];
	}
#endif
}

#pragma mark - Helpers

- (UIActivityViewController *)activityViewControllerForItem:(NSDictionary *)item viewController:(UIViewController*)viewController sender:(id)sender typeIdentifier:(NSString *)typeIdentifier {
#ifdef __IPHONE_8_0
    
	NSItemProvider *itemProvider = [[NSItemProvider alloc] initWithItem:item typeIdentifier:typeIdentifier];

	NSExtensionItem *extensionItem = [[NSExtensionItem alloc] init];
	extensionItem.attachments = @[ itemProvider ];

	UIActivityViewController *controller = [[UIActivityViewController alloc] initWithActivityItems:@[ extensionItem ]  applicationActivities:nil];

	if ([sender isKindOfClass:[UIBarButtonItem class]]) {
		controller.popoverPresentationController.barButtonItem = sender;
	}
	else if ([sender isKindOfClass:[UIView class]]) {
		controller.popoverPresentationController.sourceView = [sender superview];
		controller.popoverPresentationController.sourceRect = [sender frame];
	}
	else {
		NSLog(@"sender can be nil on iPhone");
	}

	return controller;
#else
    return nil;
#endif
}


#pragma mark - Errors

+ (NSError *)systemAppExtensionAPINotAvailableError {
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"App Extension API is not available is this version of iOS", @"1Password App Extension Error Message") };
	return [NSError errorWithDomain:AppExtensionErrorDomain code:AppExtensionErrorCodeAPINotAvailable userInfo:userInfo];
}


+ (NSError *)extensionCancelledByUserError {
	NSDictionary *userInfo = @{ NSLocalizedDescriptionKey : NSLocalizedString(@"1Password Extension was cancelled by the user", @"1Password App Extension Error Message") };
	return [NSError errorWithDomain:AppExtensionErrorDomain code:AppExtensionErrorCodeCancelledByUser userInfo:userInfo];
}

+ (NSError *)failedToContactExtensionErrorWithActivityError:(NSError *)activityError {
	NSMutableDictionary *userInfo = [NSMutableDictionary new];
	userInfo[NSLocalizedDescriptionKey] = NSLocalizedString(@"Failed to contacting the 1Password App Extension", @"1Password App Extension Error Message");
	if (activityError) {
		userInfo[NSUnderlyingErrorKey] = activityError;
	}

	return [NSError errorWithDomain:AppExtensionErrorDomain code:AppExtensionErrorCodeFailedToContactExtension userInfo:userInfo];
}

+ (NSError *)failedToCollectFieldsErrorWithUnderlyingError:(NSError *)underlyingError {
	NSMutableDictionary *userInfo = [NSMutableDictionary new];
	userInfo[NSLocalizedDescriptionKey] = NSLocalizedString(@"Failed to execute script that collects web page information", @"1Password App Extension Error Message");
	if (underlyingError) {
		userInfo[NSUnderlyingErrorKey] = underlyingError;
	}

	return [NSError errorWithDomain:AppExtensionErrorDomain code:AppExtensionErrorCodeCollectFieldsScriptFailed userInfo:userInfo];
}

+ (NSError *)failedToFillFieldsErrorWithLocalizedErrorMessage:(NSString *)errorMessage underlyingError:(NSError *)underlyingError {
	NSMutableDictionary *userInfo = [NSMutableDictionary new];
	if (errorMessage) {
		userInfo[NSLocalizedDescriptionKey] = errorMessage;
	}
	if (underlyingError) {
		userInfo[NSUnderlyingErrorKey] = underlyingError;
	}

	return [NSError errorWithDomain:AppExtensionErrorDomain code:AppExtensionErrorCodeFillFieldsScriptFailed userInfo:userInfo];
}

+ (NSError *)failedToLoadItemProviderDataErrorWithUnderlyingError:(NSError *)underlyingError {
	NSMutableDictionary *userInfo = [NSMutableDictionary new];
	userInfo[NSLocalizedDescriptionKey] = NSLocalizedString(@"Failed to parse information returned by 1Password App Extension", @"1Password App Extension Error Message");
	if (underlyingError) {
		userInfo[NSUnderlyingErrorKey] = underlyingError;
	}

	return [[NSError alloc] initWithDomain:AppExtensionErrorDomain code:AppExtensionErrorCodeFailedToLoadItemProviderData userInfo:userInfo];
}

#pragma mark - App Extension ItemProvider Callback

#ifdef __IPHONE_8_0
- (void)processExtensionItem:(NSExtensionItem *)extensionItem completion:(void (^)(NSDictionary *loginDictionary, NSError *error))completion {
	if (extensionItem.attachments.count == 0) {
		NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Unexpected data returned by App Extension: extension item had no attachments." };
		NSError *error = [[NSError alloc] initWithDomain:AppExtensionErrorDomain code:AppExtensionErrorCodeUnexpectedData userInfo:userInfo];
		if (completion) {
			completion(nil, error);
		}
		return;
	}
	
	NSItemProvider *itemProvider = extensionItem.attachments[0];
	if (![itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypePropertyList]) {
		NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Unexpected data returned by App Extension: extension item attachment does not conform to kUTTypePropertyList type identifier" };
		NSError *error = [[NSError alloc] initWithDomain:AppExtensionErrorDomain code:AppExtensionErrorCodeUnexpectedData userInfo:userInfo];
		if (completion) {
			completion(nil, error);
		}
		return;
	}


	[itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypePropertyList options:nil completionHandler:^(NSDictionary *loginDictionary, NSError *itemProviderError)
	{
		NSError *error = nil;
		if (!loginDictionary) {
			NSLog(@"Failed to loadItemForTypeIdentifier: %@", itemProviderError);
			error = [OnePasswordExtension failedToLoadItemProviderDataErrorWithUnderlyingError:itemProviderError];
		}

		if (completion) {
			if ([NSThread isMainThread]) {
				completion(loginDictionary, error);
			}
			else {
				dispatch_async(dispatch_get_main_queue(), ^{
					completion(loginDictionary, error);
				});
			}
		}
	}];
}


#pragma mark - Web view integration

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
- (void)fillLoginIntoWKWebView:(WKWebView *)webView forViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(BOOL success, NSError *error))completion {
	__weak typeof (self) miniMe = self;
	[webView evaluateJavaScript:OPWebViewCollectFieldsScript completionHandler:^(NSString *result, NSError *error) {
		if (!result) {
			NSLog(@"1Password Extension failed to collect web page fields: %@", error);
			if (completion) {
				completion(NO,[OnePasswordExtension failedToCollectFieldsErrorWithUnderlyingError:error]);
			}

			return;
		}
		
		__strong typeof(self) strongMe = miniMe;
		[strongMe findLoginIn1PasswordWithURLString:webView.URL.absoluteString collectedPageDetails:result forWebViewController:viewController sender:sender withWebView:webView completion:^(BOOL success, NSError *error) {
			if (completion) {
				completion(success, error);
			}
		}];
	}];
}
#endif

- (void)fillLoginIntoUIWebView:(UIWebView *)webView webViewController:(UIViewController *)viewController sender:(id)sender completion:(void (^)(BOOL success, NSError *error))completion {
	NSString *collectedPageDetails = [webView stringByEvaluatingJavaScriptFromString:OPWebViewCollectFieldsScript];
	[self findLoginIn1PasswordWithURLString:webView.request.URL.absoluteString collectedPageDetails:collectedPageDetails forWebViewController:viewController sender:sender withWebView:webView completion:^(BOOL success, NSError *error) {
		if (completion) {
			completion(success, error);
		}
	}];
}

- (void)findLoginIn1PasswordWithURLString:URLString collectedPageDetails:(NSString *)collectedPageDetails forWebViewController:(UIViewController *)forViewController sender:(id)sender withWebView:(id)webView completion:(void (^)(BOOL success, NSError *error))completion
{
	NSDictionary *item = @{ AppExtensionVersionNumberKey : VERSION_NUMBER, AppExtensionURLStringKey : URLString, AppExtensionWebViewPageDetails : collectedPageDetails };

	__weak typeof (self) miniMe = self;

	UIActivityViewController *activityViewController = [self activityViewControllerForItem:item viewController:forViewController sender:sender typeIdentifier:kUTTypeAppExtensionFillWebViewAction];
	activityViewController.completionWithItemsHandler = ^(NSString *activityType, BOOL completed, NSArray *returnedItems, NSError *activityError) {
		if (returnedItems.count == 0) {
			NSError *error = nil;
			if (activityError) {
				NSLog(@"Failed to findLoginIn1PasswordWithURLString: %@", activityError);
				error = [OnePasswordExtension failedToContactExtensionErrorWithActivityError:activityError];
			}
			else {
				error = [OnePasswordExtension extensionCancelledByUserError];
			}

			if (completion) {
				completion(NO, error);
			}

			return;
		}

		__strong typeof(self) strongMe = miniMe;
		[strongMe processExtensionItem:returnedItems[0] completion:^(NSDictionary *loginDictionary, NSError *error) {
			if (!loginDictionary) {
				if (completion) {
					completion(NO, error);
				}

				return;
			}
			
			__strong typeof(self) strongMe2 = miniMe;
			NSString *fillScript = loginDictionary[AppExtensionWebViewPageFillScript];
			[strongMe2 executeFillScript:fillScript inWebView:webView completion:^(BOOL success, NSError *error) {
				if (completion) {
					completion(success, error);
				}
			}];
		}];
	};
	
	[forViewController presentViewController:activityViewController animated:YES completion:nil];
}

- (void)executeFillScript:(NSString *)fillScript inWebView:(id)webView completion:(void (^)(BOOL success, NSError *error))completion
{
	if (!fillScript) {
		NSLog(@"Failed to executeFillScript, fillScript is missing");
		if (completion) {
			completion(NO, [OnePasswordExtension failedToFillFieldsErrorWithLocalizedErrorMessage:NSLocalizedString(@"Failed to fill web page because script is missing", @"1Password App Extension Error Message") underlyingError:nil]);
		}

		return;
	}
	
	NSMutableString *scriptSource = [OPWebViewFillScript mutableCopy];
	[scriptSource appendFormat:@"('%@');", fillScript];
	
	if ([webView isKindOfClass:[UIWebView class]]) {
		NSString *result = [((UIWebView *)webView) stringByEvaluatingJavaScriptFromString:scriptSource];
		BOOL success = (result != nil);
		NSError *error = nil;

		if (!success) {
			NSLog(@"Cannot executeFillScript, stringByEvaluatingJavaScriptFromString failed");
			error = [OnePasswordExtension failedToFillFieldsErrorWithLocalizedErrorMessage:NSLocalizedString(@"Failed to fill web page because script could not be evaluated", @"1Password App Extension Error Message") underlyingError:nil];
		}

		if (completion) {
			completion(success, error);
		}

		return;
	}

#if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_8_0
	if ([webView isKindOfClass:[WKWebView class]]) {
		[((WKWebView *)webView) evaluateJavaScript:scriptSource completionHandler:^(NSString *result, NSError *evaluationError) {
			BOOL success = (result != nil);
			NSError *error = nil;

			if (!success) {
				NSLog(@"Cannot executeFillScript, evaluateJavaScript failed: %@", evaluationError);
				error = [OnePasswordExtension failedToFillFieldsErrorWithLocalizedErrorMessage:NSLocalizedString(@"Failed to fill web page because script could not be evaluated", @"1Password App Extension Error Message") underlyingError:error];
			}

			if (completion) {
				completion(success, error);
			}
		}];

		return;
	}
#endif

	[NSException raise:@"Invalid argument: web view must be an instance of WKWebView or UIWebView." format:@""];
}
#endif


#pragma mark - WebView field collection and filling scripts

NSString *const OPWebViewCollectFieldsScript = @"var f;document.collect=l;function l(a,b){var c=Array.prototype.slice.call(a.querySelectorAll('input, select'));f=b;c.forEach(p);return c.filter(function(a){q(a,['select','textarea'])?a=!0:q(a,'input')?(a=(a.getAttribute('type')||'').toLowerCase(),a=!('button'===a||'submit'===a||'reset'==a||'file'===a||'hidden'===a||'image'===a)):a=!1;return a}).map(s)}function s(a,b){var c=a.opid,d=a.id||a.getAttribute('id')||null,g=a.name||null,z=a['class']||a.getAttribute('class')||null,A=a.rel||a.getAttribute('rel')||null,B=String.prototype.toLowerCase.call(a.type||a.getAttribute('type')),C=a.value,D=-1==a.maxLength?999:a.maxLength,E=a.getAttribute('x-autocompletetype')||a.getAttribute('autocompletetype')||a.getAttribute('autocomplete')||null,k;k=[];var h,n;if(a.options){h=0;for(n=a.options.length;h<n;h++)k.push([t(a.options[h].text),a.options[h].value]);k={options:k}}else k=null;h=u(a);n=v(a);var H=w(a),I=t(a.getAttribute('data-label')),J=t(a.getAttribute('aria-label')),K=t(a.placeholder),M=x(a),m;m=[];for(var e=a;e&&e.nextSibling;){e=e.nextSibling;if(y(e))break;F(m,e)}m=t(m.join(''));e=[];G(a,e);var e=t(e.reverse().join('')),r;a.form?(a.form.opid=a.form.opid||L.a(),a.form.opdata=a.form.opdata||{htmlName:a.form.getAttribute('name'),htmlID:a.form.getAttribute('id'),htmlAction:N(a.form.getAttribute('action')),htmlMethod:a.form.getAttribute('method'),opid:a.form.opid},r=a.form.opdata):r=null;return{opid:c,elementNumber:b,htmlID:d,htmlName:g,htmlClass:z,rel:A,type:B,value:C,maxLength:D,autoCompleteType:E,selectInfo:k,visible:h,viewable:n,'label-tag':H,'label-data':I,'label-aria':J,placeholder:K,'label-top':M,'label-right':m,'label-left':e,form:r}}function p(a,b){a.opid='__'+f+'__'+b+'__'};function x(a){var b;for(a=a.parentElement||a.parentNode;a&&'td'!=(a?(a.tagName||'').toLowerCase():'');)a=a.parentElement||a.parentNode;if(!a||void 0===a)return null;b=a.parentElement||a.parentNode;if(!q(b,'tr'))return null;b=b.previousElementSibling;if(!q(b,'tr')||b.cells&&a.cellIndex>=b.cells.length)return null;a=b.cells[a.cellIndex];return t(a.innerText||a.textContent)}function w(a){var b=a.id,c=a.name,d=a.ownerDocument;if(void 0===b&&void 0===c)return null;b=O(String.prototype.replace.call(b,\"'\",\"\\\\'\"));c=O(String.prototype.replace.call(c,\"'\",\"\\\\'\"));if(b=d.querySelector(\"label[for='\"+b+\"']\")||d.querySelector(\"label[for='\"+c+\"']\"))return t(b.innerText||b.textContent);do{if('label'===(''+a.tagName).toLowerCase())return t(a.innerText||a.textContent);a=a.parentNode}while(a&&a!=d);return null};function t(a){var b=null;a&&(b=a.toLowerCase().replace(/\\s/mg,'').replace(/[~`!@$%^&*()\\-_+=:;'\"\\[\\]|\\\\,<.>\\/?]/mg,''),b=0<b.length?b:null);return b}function F(a,b){var c;c='';3===b.nodeType?c=b.nodeValue:1===b.nodeType&&(c=b.innerText||b.textContent);(c=t(c))&&a.push(c)}function y(a){return a&&void 0!==a?q(a,'select option input form textarea iframe button'.split(' ')):!0}function G(a,b,c){var d;for(c||(c=0);a&&a.previousSibling;){a=a.previousSibling;if(y(a))return;F(b,a)}if(a&&0===b.length){for(d=null;!d;){a=a.parentElement||a.parentNode;if(!a)return;for(d=a.previousSibling;d&&!y(d)&&d.lastChild;)d=d.lastChild}y(d)||(F(b,d),0===b.length&&G(d,b,c+1))}}function q(a,b){var c;if(!a)return!1;c=a?(a.tagName||'').toLowerCase():'';return b.constructor==Array?0<=b.indexOf(c):c===b}function v(a){var b,c,d,g;if(!a||!a.offsetParent)return!1;c=a.ownerDocument.documentElement;d=a.getBoundingClientRect();g=c.getBoundingClientRect();b=d.left-c.clientLeft;c=d.top-c.clientTop;if(0>b||b>g.width||0>c||c>g.height)return u(a);if(b=a.ownerDocument.elementFromPoint(b+3,c+3)){if('label'===(b.tagName||'').toLowerCase())return g=String.prototype.replace.call(a.id,\"'\",\"\\\\'\"),c=String.prototype.replace.call(a.name,\"'\",\"\\\\'\"),a=a.ownerDocument.querySelector(\"label[for='\"+g+\"']\")||a.ownerDocument.querySelector(\"label[for='\"+c+\"']\"),b===a;if(b.tagName===a.tagName)return!0}return!1}function u(a){var b=a;a=(a=a.ownerDocument)?a.defaultView:{};for(var c;b&&b!==document;){c=a.getComputedStyle?a.getComputedStyle(b,null):b.style;if('none'===c.display||'hidden'==c.visibility)return!1;b=b.parentNode}return b===document}function O(a){return a?a.replace(/([:\\\\.'])/g,'\\\\$1'):null};var P=/^[\\/\\?]/;function N(a){if(!a)return null;if(0==a.indexOf('http'))return a;var b=window.location.protocol+'//'+window.location.hostname;window.location.port&&''!=window.location.port&&(b+=':'+window.location.port);a.match(P)||(a='/'+a);return b+a}var L=new function(){return{a:function(){function a(){return(65536*(1+Math.random())|0).toString(16).substring(1).toUpperCase()}return[a(),a(),a(),a(),a(),a(),a(),a()].join('')}}}; (function collect(uuid) { var fields = document.collect(document, uuid); return { 'url': document.baseURI, 'fields': fields }; })('uuid');";

NSString *const OPWebViewFillScript = @"var e=!0,h=!0;document.fill=k;function k(a){var b,c=[],d=a.properties,f=1,g;d&&d.delay_between_operations&&(f=d.delay_between_operations);if(null!=a.savedURL&&0===a.savedURL.indexOf('https://')&&'http:'==document.location.protocol&&(b=confirm('This page is not protected. Any information you submit can potentially be seen by others. This login was originally saved on a secure page, so it is possible you are being tricked into revealing your login information.\\n\\nDo you still wish to fill this login?'),!1==b))return;g=function(a,b){var d=a[0];void 0===d?b():('delay'===d.operation?f=d.parameters[0]:c.push(l(d)),setTimeout(function(){g(a.slice(1),b)},f))};if(b=a.options)h=b.animate,e=b.markFilling;a.hasOwnProperty('script')&&(b=a.script,g(b,function(){c=Array.prototype.concat.apply(c,void 0);a.hasOwnProperty('autosubmit')&&setTimeout(function(){autosubmit(a.autosubmit,d.allow_clicky_autosubmit)},AUTOSUBMIT_DELAY);'object'==typeof protectedGlobalPage&&protectedGlobalPage.a('fillItemResults',{documentUUID:documentUUID,fillContextIdentifier:a.fillContextIdentifier,usedOpids:c},function(){})}))}var t={fill_by_opid:m,fill_by_query:n,click_on_opid:p,click_on_query:q,touch_all_fields:r,simple_set_value_by_query:s,delay:null};function l(a){var b;if(!a.hasOwnProperty('operation')||!a.hasOwnProperty('parameters'))return null;b=a.operation;return t.hasOwnProperty(b)?t[b].apply(this,a.parameters):null}function m(a,b){var c;return(c=u(a))?(v(c,b),c.opid):null}function n(a,b){var c;c=document.querySelectorAll(a);return Array.prototype.map.call(c,function(a){v(a,b);return a.opid},this)}function s(a,b){var c,d=[];c=document.querySelectorAll(a);Array.prototype.forEach.call(c,function(a){void 0!==a.value&&(a.value=b,d.push(a.opid))});return d}function p(a){a=u(a);w(a);'function'===typeof a.click&&a.click();return a?a.opid:null}function q(a){a=document.querySelectorAll(a);return Array.prototype.map.call(a,function(a){w(a);'function'===typeof a.click&&a.click();'function'===typeof a.focus&&a.focus();return a.opid},this)}function r(){x()};var y={'true':!0,y:!0,1:!0,yes:!0,'✓':!0},z=200;function v(a,b){var c;if(a&&null!==b&&void 0!==b)switch(e&&a.form&&!a.form.opfilled&&(a.form.opfilled=!0),a.type?a.type.toLowerCase():null){case 'checkbox':c=b&&1<=b.length&&y.hasOwnProperty(b.toLowerCase())&&!0===y[b.toLowerCase()];a.checked===c||A(a,function(a){a.checked=c});break;case 'radio':!0===y[b.toLowerCase()]&&a.click();break;default:a.value==b||A(a,function(a){a.value=b})}}function A(a,b){B(a);b(a);C(a);D(a)&&(a.className+=' com-agilebits-onepassword-extension-animated-fill',setTimeout(function(){a&&a.className&&(a.className=a.className.replace(/(\\s)?com-agilebits-onepassword-extension-animated-fill/,''))},z))};function E(a,b){var c;c=a.ownerDocument.createEvent('KeyboardEvent');c.initKeyboardEvent?c.initKeyboardEvent(b,!0,!0):c.initKeyEvent&&c.initKeyEvent(b,!0,!0,null,!1,!1,!1,!1,0,0);a.dispatchEvent(c)}function B(a){w(a);a.focus();E(a,'keydown');E(a,'keyup');E(a,'keypress')}function C(a){var b=a.ownerDocument.createEvent('HTMLEvents'),c=a.ownerDocument.createEvent('HTMLEvents');E(a,'keydown');E(a,'keyup');E(a,'keypress');c.initEvent('input',!0,!0);a.dispatchEvent(c);b.initEvent('change',!0,!0);a.dispatchEvent(b);a.blur()}function w(a){!a||a&&'function'!==typeof a.click||a.click()}function F(){var a=RegExp('(pin|password|passwort|kennwort|passe|contraseña|senha|密码|adgangskode|hasło|wachtwoord)','i');return Array.prototype.slice.call(document.querySelectorAll(\"input[type='text']\")).filter(function(b){return b.value&&a.test(b.value)},this)}function x(){F().forEach(function(a){B(a);a.click&&a.click();C(a)})}function D(a){var b;if(b=h)a:{b=a;for(var c=a.ownerDocument,c=c?c.defaultView:{},d;b&&b!==document;){d=c.getComputedStyle?c.getComputedStyle(b,null):b.style;if('none'===d.display||'hidden'==d.visibility){b=!1;break a}b=b.parentNode}b=b===document}return b?-1!=='email text password number tel url'.split(' ').indexOf(a.type||''):!1}function u(a){var b,c,d;if(a)for(d=document.querySelectorAll('input, select'),b=0,c=d.length;b<c;b++)if(d[b].opid==a)return d[b];return null}; (function execute_fill_script(scriptJSON) { var script = null, error = null; try { script = JSON.parse(scriptJSON);} catch (e) { error = e; } if (!script) { return { 'success': false, 'error': 'Unable to parse fill script JSON. Javascript exception: ' + error }; } document.fill(script); return {'success': true}; })";

@end
