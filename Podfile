use_frameworks!

platform :ios, '15.0'

#source 'https://cdn.cocoapods.org/'
#source 'https://cocoapods-cdn.netlify.app/'
source 'https://github.com/CocoaPods/Specs.git'

target 'OnionBrowser' do
  pod 'DTFoundation/DTASN1'
  pod 'TUSafariActivity'

  pod 'SDCAlertView', '~> 10'
  pod 'FavIcon', :git => 'https://github.com/tladesignz/FavIcon.git'
  pod 'MBProgressHUD', '~> 1.2'
  pod 'Eureka', '~> 5.3'
  pod 'ImageRow', '~> 4.1'

  pod 'OrbotKit', '~> 1.0'
end

target 'OnionBrowser Tests' do
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
  
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
      end
    end
  end
end

