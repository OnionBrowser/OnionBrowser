use_frameworks!

platform :ios, '15.0'

#source 'https://cdn.cocoapods.org/'
#source 'https://cocoapods-cdn.netlify.app/'
source 'https://github.com/CocoaPods/Specs.git'

target 'OnionBrowser' do
  pod 'DTFoundation/DTASN1'
  pod 'TUSafariActivity'

  pod 'SDCAlertView', '~> 12'
  pod 'FavIcon', :git => 'https://github.com/tladesignz/FavIcon.git'
  pod 'MBProgressHUD', '~> 1.2'
  pod 'Eureka', '~> 5.5'
  pod 'ImageRow', :git => 'https://github.com/erickyim/ImageRow.git', :commit => 'd38369b8894425a9225ccf1e267226833b1950f0'

  pod 'SwiftSoup', '~> 2.7'

  pod 'Tor/GeoIP',
#    :podspec => 'https://raw.githubusercontent.com/iCepa/Tor.framework/refs/heads/pure_pod/Arti.podspec'
    '~> 409.11'
#    :path => '../Tor.framework'

  pod 'IPtProxyUI',
    '~> 5.4'
#    :git => 'https://github.com/tladesignz/IPtProxyUI-ios'
#    :path => '../IPtProxyUI'

  pod 'OrbotKit', '~> 1.1'
end

target 'OnionBrowser Tests' do
  pod 'OCMock'
  pod 'DTFoundation/DTASN1'
end

# Fix Xcode 15 compile issues.
post_install do |installer|
  installer.pods_project.targets.each do |target|
    if target.respond_to?(:name) and !target.name.start_with?("Pods-")
      target.build_configurations.each do |config|
        if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'].to_f < 15
          config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
        end
      end
    end
  end
end
