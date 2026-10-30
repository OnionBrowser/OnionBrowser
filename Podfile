use_frameworks!

platform :ios, '15.0'

#source 'https://cdn.cocoapods.org/'
#source 'https://cocoapods-cdn.netlify.app/'
source 'https://github.com/CocoaPods/Specs.git'

target 'OnionBrowser' do
  pod 'FavIcon', :git => 'https://github.com/tladesignz/FavIcon.git'

  pod 'OrbotKit', '~> 1.1'
end

target 'OnionBrowser Tests' do
  pod 'OCMock'
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
