platform :ios, '17.0'

install! 'cocoapods',
  :deterministic_uuids => true

use_frameworks! :linkage => :static

target 'SlotMachineSuite' do
  project 'SlotMachineSuite.xcodeproj'

  # Attribution stack. Adjust ODM requires Adjust iOS SDK 5.4.1+.
  pod 'AppsFlyerFramework', '>= 7.0.0'
  pod 'Adjust/AdjustGoogleOdm', '>= 5.4.1'
  pod 'GoogleAdsOnDeviceConversion'

  # Statsig client SDK (Swift and Objective-C).
  pod 'Statsig', '~> 1.62.9'
end

post_install do |installer|
  # Older podspecs (including Statsig's privacy bundle) still declare iOS 10.
  # Raise only unsupported values; the app itself continues to require iOS 17.
  minimum_pod_ios = Gem::Version.new('12.0')
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |configuration|
      deployment_target = configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
      next unless deployment_target
      next unless Gem::Version.new(deployment_target) < minimum_pod_ios

      configuration.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = minimum_pod_ios.to_s
    end
  end
end
