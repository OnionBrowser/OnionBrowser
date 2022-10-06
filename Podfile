use_frameworks!

platform :ios, '11.4'

#source 'https://cdn.cocoapods.org/'
#source 'https://cocoapods-cdn.netlify.app/'
source 'https://github.com/CocoaPods/Specs.git'

target 'OnionBrowser2' do
  pod 'DTFoundation/DTASN1'
  pod 'TUSafariActivity'
  pod 'VForceTouch'

  pod 'CSPHeader', '~> 0.6'

  pod 'SDCAlertView', '~> 10'
  pod 'FavIcon', :git => 'https://github.com/tladesignz/FavIcon.git'
  pod 'MBProgressHUD', '~> 1.2'

  pod 'Tor/OCSPCache', :podspec => 'https://raw.githubusercontent.com/tladesignz/Tor.framework/ocspcache/Tor.podspec' #:git => 'https://github.com/tladesignz/Tor.framework.git', :branch => 'ocspcache'

  pod 'IPtProxyUI', '~> 1.10'
end

target 'OnionBrowser2 Tests' do
  pod 'OCMock'
  pod 'DTFoundation/DTASN1'
end

# Fix Xcode 14 code signing issues with bundles.
# See https://github.com/CocoaPods/CocoaPods/issues/8891#issuecomment-1249151085
post_install do |installer|
	installer.pods_project.targets.each do |target|
		if target.respond_to?(:product_type) and target.product_type == "com.apple.product-type.bundle"
			target.build_configurations.each do |config|
					config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
			end
		end
	end
end
