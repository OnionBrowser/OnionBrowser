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

  pod 'Eureka', '~> 5.3.2'
  pod 'ImageRow', '~> 4.0'
  pod 'Reachability', '~> 3.2'
  pod 'SDCAlertView', '~> 10'
  pod 'FavIcon', git: 'https://github.com/tladesignz/FavIcon.git', branch: 'swift-5'
  pod 'MBProgressHUD', '~> 1.2'

  pod 'IPtProxy', '~> 1.0' # :path => '../IPtProxy' #
  pod 'Tor', podspec: 'https://raw.githubusercontent.com/iCepa/Tor.framework/v405.7.1/Tor.podspec'
end

target 'OnionBrowser2 Tests' do
  pod 'OCMock'
  pod 'DTFoundation/DTASN1'
end
