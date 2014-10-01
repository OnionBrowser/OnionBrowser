# 1Password App Extension

Welcome! With just a few lines of code, your app can add 1Password support, enabling your users to:

1. Access their 1Password Logins to automatically fill your login page.
2. Use the Strong Password Generator to create unique passwords during registration, and save the new Login within 1Password.
3. Quickly fill 1Password Logins directly into web views.

Empowering your users to use strong, unique passwords has never been easier. Let's get started!

## App Extension in Action

<a href="https://vimeo.com/102142106" target="_blank"><img src="http://cl.ly/image/3Q232U370v0W/1PasswordAppExtensionPlayVideo.png" width="640" height="360"></a>


## Just Give Me the Code (TL;DR)

You might be looking at this 13 KB README and think integrating with 1Password is very complicated. Nothing could be further from the truth!

If you're the type that just wants the code, here it is:

* [OnePasswordExtension.h](https://raw.githubusercontent.com/AgileBits/onepassword-app-extension/master/OnePasswordExtension.h?token=110676__eyJzY29wZSI6IlJhd0Jsb2I6QWdpbGVCaXRzL29uZXBhc3N3b3JkLWFwcC1leHRlbnNpb24vbWFzdGVyL09uZVBhc3N3b3JkRXh0ZW5zaW9uLmgiLCJleHBpcmVzIjoxNDA3Mjg0MTMwfQ%3D%3D--3867c64b22a5923bead5948001ce2ff048892799)
* [OnePasswordExtension.m](https://raw.githubusercontent.com/AgileBits/onepassword-app-extension/master/OnePasswordExtension.m?token=110676__eyJzY29wZSI6IlJhd0Jsb2I6QWdpbGVCaXRzL29uZXBhc3N3b3JkLWFwcC1leHRlbnNpb24vbWFzdGVyL09uZVBhc3N3b3JkRXh0ZW5zaW9uLm0iLCJleHBpcmVzIjoxNDA3Mjg0MTA5fQ%3D%3D--05c6ea9c73d0afb9f30e53a31d81df00b7c02077)

Simply include these two files in your project, add a button with a [1Password login image](https://github.com/AgileBits/onepassword-app-extension/tree/master/1Password.xcassets) on it to your view, set the button's action to call the appropriate OnePasswordExtension method, and you're all set!


## Running the Sample Apps

Adding 1Password support to your app is easy. To demonstrate how it works, we have two sample apps for iOS that showcase all of the 1Password features.


### Step 1: Download the Source Code and Sample Apps

To get started, download the 1Password Extension project from https://github.com/AgileBits/onepassword-app-extension/archive/master.zip, or [clone it from GitHub](https://github.com/AgileBits/onepassword-app-extension).

Inside the downloaded folder, you'll find the resources needed to integrate with 1Password, such as images and sample code. The sample code includes two apps from ACME Corporation: one that demonstrates how to integrate the 1Password Login and Registration features, as well as a web browser that showcases the web view Filling feature.

The 1Password extension is also available via cocoapods, simply add `pod '1PasswordExtension', '~> 1.0.0'` to your Podfile, run `pod install` from your project directory and you're ready to go.

### Step 2: Install the Latest 1Password & Xcode Betas

The sample project depends upon having the latest version of Xcode 6, as well as the 1Password Beta installed on your iOS device.

<!---
If you are developing for OS X, you can enable betas within the 1Password > Preferences > Updates window (as shown [here](i.agilebits.com/Preferences_197C0C6B.png)) and enabling the _Include beta builds_ checkbox. Mac App Store users should [download the web store version](https://agilebits.com/downloads) in order to enable betas.
-->

To install the 1Password Beta, you will need to enroll in the 1Password for iOS Beta program. Please email [support+appex@agilebits.com](mailto:support+appex@agilebits.com) to express your interest. Let us know that you're an app developer and planning to add 1Password support.

Beta enrollment is a manual process so please allow a bit of time to hear back from us.


### Step 3: Run the Apps

Open `1Password Extension Demos` Xcode workspace from within the `Demos` folder with Xcode 6, and then select the `ACME` target and set it to run your iOS device:

<img src="http://i.agilebits.com/dt/Menubar_and_SignInViewController_m_and_README_md_—_onepassword-extension__git__master__197DEA31.png" width="342" height="150">

Since you will not have 1Password running within your iOS Simulator, it is important that you run on your device.

If all goes well, The ACME app will launch and you'll be able to test the 1Password App Extension. The first time you attempt to access the 1Password extension you will need to enable it by tapping on the _More_ button in the activity sheet and then enabling the _1Password Beta_ item in the _Activities_ list. If the 1Password icons are missing, it likely means you do not have the 1Password Beta installed.

Back in Xcode you can change the scheme to ACME Browser to test the web view filling feature.

## Integrating 1Password With Your App

Once you've verified your setup by testing the sample applications, it is time to get your hands dirty and see exactly how to add 1Password into your app.

Be forewarned, however, that there is not much code to get dirty with. If you were looking for an SDK to spend days of your life on, you'll be sorely disappointed.


### Add 1Password Files to Your Project

Add the `OnePasswordExtension.h`, `OnePasswordExtension.m`, and `1Password.xcassets` to your project and import `OnePasswordExtension.h` in your view contoller that implements the action for the 1Password button.

<img src="http://cl.ly/image/2g3B1r2O2z0L/Image%202014-07-29%20at%209.19.36%20AM.png" width="260" height="237"/>

### Use Case #1: Native App Login

In this use case we'll learn how to enable your existing users to fill their credentials into your native app's login form. If your application is using a web view to login (i.e. OAuth), you'll want to follow the web view integration steps in Use Case #3.

The first step is to add a UIButton to your login page. Use an existing 1Password image from the _1Password.xcassets_ catalog so users recognize the button.

You'll need to hide this button (or educate users on the benefits of strong, unique passwords) if no password manager is installed. You can use `isAppExtensionAvailable` to determine availability and hide the button if it isn't. For example:

```objective-c
-(void)viewDidLoad {
	[super viewDidLoad];
	[self.onepasswordSigninButton setHidden:![[OnePasswordExtension sharedExtension] isAppExtensionAvailable]];
}
```

Note that `isAppExtensionAvailable` looks to see if any app is installed that supports the generic `org-appextension-feature-password-management` feature. Any application that supports password management actions can be used.

Next we need to wire up the action for this button to this method in your UIViewController:

```objective-c
- (IBAction)findLoginFrom1Password:(id)sender {
	__weak typeof (self) miniMe = self;
	[[OnePasswordExtension sharedExtension] findLoginForURLString:@"https://www.acme.com" forViewController:self sender:sender completion:^(NSDictionary *loginDict, NSError *error) {
		if (!loginDict) {
			if (error.code != AppExtensionErrorCodeCancelledByUser) {
				NSLog(@"Error invoking 1Password App Extension for find login: %@", error);
			}
			return;
		}
		
		__strong typeof(self) strongMe = miniMe;
		strongMe.usernameTextField.text = loginDict[AppExtensionUsernameKey];
		strongMe.passwordTextField.text = loginDict[AppExtensionPasswordKey];
	}];
}
```

Aside from the [weak/strong self dance](http://dhoerl.wordpress.com/2013/04/23/i-finally-figured-out-weakself-and-strongself/), this code is pretty straight forward:

1. Provide a `URLString` that uniquely identifies your service. For example, if your app required a Twitter login, you would pass in `@"https://twitter.com"`. See _Best Practices_ for details.
2. Pass in the `UIViewController` that you want the share sheet to be presented upon.
3. Provide a completion block that will be called when the user finishes their selection. This block is guaranteed to be called on the main thread.
4. Extract the needed information from the login dictionary and update your UI elements.


### Use Case #2: New User Registration

Allow your users to access 1Password directly from your registration page so they can generate strong, unique passwords. 1Password will also save the login for future use, allowing users to easily log into your app on their other devices. The newly saved login and generated password are returned to you so you can update your UI and complete the registration.

Adding 1Password to your registration screen is very similar to adding 1Password to your login screen. In this case you'll wire the 1Password button to an action like this:

```objective-c
- (IBAction)saveLoginTo1Password:(id)sender {
	NSDictionary *newLoginDetails = @{
		AppExtensionTitleKey: @"ACME",
		AppExtensionUsernameKey: self.usernameTextField.text ? : @"",
		AppExtensionPasswordKey: self.passwordTextField.text ? : @"",
		AppExtensionNotesKey: @"Saved with the ACME app",
		AppExtensionSectionTitleKey: @"ACME Browser",
		AppExtensionFieldsKey: @{
			  @"firstname" : self.firstnameTextField.text ? : @"",
			  @"lastname" : self.lastnameTextField.text ? : @""
			  // Add as many string fields as you please.
		}
	};
	
	// Password generation options are optional, but are very handy in case you have strict rules about password lengths
	NSDictionary *passwordGenerationOptions = @{
		AppExtensionGeneratedPasswordMinLengthKey: @(6),
		AppExtensionGeneratedPasswordMaxLengthKey: @(50)
	};

	__weak typeof (self) miniMe = self;

	[[OnePasswordExtension sharedExtension] storeLoginForURLString:@"https://www.acme.com" loginDetails:newLoginDetails passwordGenerationOptions:passwordGenerationOptions forViewController:self sender:sender completion:^(NSDictionary *loginDict, NSError *error) {

		if (!loginDict) {
			if (error.code != AppExtensionErrorCodeCancelledByUser) {
				NSLog(@"Failed to use 1Password App Extension to save a new Login: %@", error);
			}
			return;
		}

		__strong typeof(self) strongMe = miniMe;

		strongMe.usernameTextField.text = loginDict[AppExtensionUsernameKey] ? : @"";
		strongMe.passwordTextField.text = loginDict[AppExtensionPasswordKey] ? : @"";
		strongMe.firstnameTextField.text = loginDict[AppExtensionReturnedFieldsKey][@"firstname"] ? : @"";
		strongMe.lastnameTextField.text = loginDict[AppExtensionReturnedFieldsKey][@"lastname"] ? : @"";
		// retrieve any additional fields that were passed in newLoginDetails dictionary
	}];
}
```

You'll notice that we're passing a lot more information into 1Password than just the `URLString` key used in the sign in example. This is because at the end of the password generation process, 1Password will create a brand new login and save it. It's not possible for 1Password to ask your app for additional information later on, so we pass in everything we can before showing the password generator screen.

An important thing to notice is the `AppExtensionURLStringKey` is set to the exact same value we used in the login scenario. This allows users to quickly find the login they saved for your app the next time they need to sign in.

### Use Case #3: Change Password

Allow your users to easily change passwords for saved logins in 1Password directly from your change password page. The updated login along with the old and the newly generated are returned to you so you can update your UI and complete the password change process. If no matching login is found in 1Password, the user will be prompted to save a new login instead.

Adding 1Password to your change password screen is very similar to adding 1Password to your login and registration screens. In this case you'll wire the 1Password button to an action like this:

```objective-c
- (IBAction)changePasswordIn1Password:(id)sender {
	NSString *changedPassword = self.freshPasswordTextField.text ? : @"";
	NSString *oldPassword = self.oldPasswordTextField.text ? : @"";
	NSString *username = [LoginInformation sharedLoginInformation].username ? : @"";

	NSDictionary *loginDetails = @{
									  AppExtensionTitleKey: @"ACME",
									  AppExtensionUsernameKey: username, // 1Password will prompt the user to create a new item if no matching logins are found with this username.
									  AppExtensionPasswordKey: changedPassword,
									  AppExtensionOldPasswordKey: oldPassword,
									  AppExtensionNotesKey: @"Saved with the ACME app",
									};

	// Password generation options are optional, but are very handy in case you have strict rules about password lengths
	NSDictionary *passwordGenerationOptions = @{
		AppExtensionGeneratedPasswordMinLengthKey: @(6),
		AppExtensionGeneratedPasswordMaxLengthKey: @(50)
	};

	__weak typeof (self) miniMe = self;

	[[OnePasswordExtension sharedExtension] changePasswordForLoginForURLString:@"https://www.acme.com" loginDetails:loginDetails passwordGenerationOptions:passwordGenerationOptions forViewController:self sender:sender completion:^(NSDictionary *loginDict, NSError *error) {
		if (!loginDict) {
			if (error.code != AppExtensionErrorCodeCancelledByUser) {
				NSLog(@"Error invoking 1Password App Extension for find login: %@", error);
			}
			return;
		}

		__strong typeof(self) strongMe = miniMe;
		strongMe.oldPasswordTextField.text = loginDict[AppExtensionOldPasswordKey];
		strongMe.freshPasswordTextField.text = loginDict[AppExtensionPasswordKey];
		strongMe.confirmPasswordTextField.text = loginDict[AppExtensionPasswordKey];
	}];
}
```

### Use Case #4: Web View Support

The 1Password App Extension is not limited to filling native UIs. With just a little bit of extra effort, users can fill `UIWebView`s and `WKWebView`s within your application as well.

Simply add a button to your UI with its action assigned to this method in your web view's UIViewController:

```objective-c
- (IBAction)fillUsing1Password:(id)sender {
	[[OnePasswordExtension sharedExtension] fillLoginIntoWebView:self.webView forViewController:self sender:sender completion:^(BOOL success, NSError *error) {
		if (!success) {
			NSLog(@"Failed to fill login in webview: <%@>", error);
		}
	}];
}
```

1Password will take care of all the details of collecting information about the currently displayed page, allow the user to select the desired login, and then fill the web form details within the page.


## Projects supporting iOS 7.1 and earlier

If your project's Deployment Target is earlier than iOS 8.0, please make sure that you link to the `MobileCoreServices` and `WebKit` frameworks.

<a href="https://vimeo.com/102142106" target="_blank"><img src="https://www.evernote.com/shard/s340/sh/7547419d-6c49-4b45-bdb1-575c28678164/49cb7e0c1f508d1f67f5cf0361d58d3a/deep/0/WebView-Demo-for-iOS.xcodeproj.png" width="640"></a>

## Best Practices

* Use the same `URLString` during Registration and Login.
* Ensure your `URLString` is set to your actual service so your users can easily find their logins within the main 1Password app.
* You should only ask for the login information of your own service or one specific to your app. Giving a URL for a service which you do not own or support may seriously break the customer's trust in your service/app.
* If you don't have a website for your app you should specify your bundle identifier as the `URLString`, like so: app://bundleIdentifier (e.g. app://com.acme.awesome-app).
* [Send us an icon](mailto:support+appex@agilebits.com) to use for our Rich Icon service so the user can see your lovely icon while creating new items.
* Use the icons provided in the `1Password.xcassets` asset catalog so users are familiar with what it will do. Contact us if you'd like additional sizes or have other special requirements.
* Enable users to set 1Password as their default browser for external web links.
* On your registration page, pre-validate fields before calling 1Password. For example, display a message if the username is not available so the user can fix it before activating 1Password.


## References

If you open up OnePasswordExtension.m and start poking around, you'll be interested in these references.

* [Apple Extension Guide](https://developer.apple.com/library/prerelease/ios/documentation/General/Conceptual/ExtensibilityPG/index.html#//apple_ref/doc/uid/TP40014214)
* [NSItemProvider](https://developer.apple.com/library/prerelease/ios/documentation/Foundation/Reference/NSItemProvider_Class/index.html#//apple_ref/doc/uid/TP40014351), [NSExtensionItem](https://developer.apple.com/library/prerelease/ios/documentation/Foundation/Reference/NSExtensionItem_Class/index.html#//apple_ref/doc/uid/TP40014375), and [UIActivityViewController](https://developer.apple.com/library/prerelease/ios/documentation/UIKit/Reference/UIActivityViewController_Class/index.html#//apple_ref/doc/uid/TP40011976) class references.


## Contact Us

Contact us, please! We'd love to hear from you about how you integrated 1Password within your app, how we can further improve things, and add your app to [apps that integrate with 1Password](http://blog.agilebits.com/2013/04/03/ios-apps-1password-integrated-support/).

You can reach us at support+appex@agilebits.com, or if you prefer, [@1PasswordBeta](https://twitter.com/1PasswordBeta) on Twitter.
