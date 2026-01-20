require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-purchasely"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "13.4" }
  s.source       = { :git => "https://github.com/Purchasely/Purchasely-ReactNative.git", :tag => "#{s.version}" }

  s.ios.deployment_target = '13.4'
  s.tvos.deployment_target = '13.4'

  s.source_files = "ios/*.{h,m,mm,swift}", "ios/Classes/**/*.{h,m,mm,swift}"
  s.requires_arc = true

  s.dependency "React-Core"
  s.dependency "Purchasely", '5.6.2'

  s.test_spec 'Tests' do |test_spec|
    test_spec.source_files = 'ios/PurchaselyTests/**/*.{h,m,mm,swift}'
    test_spec.frameworks = 'XCTest'
  end
end
