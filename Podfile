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
end
