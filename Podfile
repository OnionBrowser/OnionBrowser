platform :ios, '11.4'

#source 'https://cdn.cocoapods.org/'
#source 'https://cocoapods-cdn.netlify.app/'
source 'https://github.com/CocoaPods/Specs.git'

target 'OnionBrowser2' do
  pod 'DTFoundation/DTASN1'
  pod 'TUSafariActivity'
  pod 'VForceTouch'

  pod 'OCSPCache', :git => 'https://github.com/Psiphon-Labs/OCSPCache'

  pod 'CSPHeader', '~> 0.6'

  pod 'ReachabilitySwift', '~> 5.0'
  pod 'SDCAlertView', '~> 10'
  pod 'FavIcon', git: 'https://github.com/tladesignz/FavIcon.git', branch: 'swift-5'
  pod 'MBProgressHUD', '~> 1.2', :modular_headers => true

  pod 'IPtProxyUI', '~> 1.1'
  pod 'Tor', '~> 406.8'
end

target 'OnionBrowser2 Tests' do
  pod 'OCMock'
  pod 'DTFoundation/DTASN1'
end
