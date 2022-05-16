require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-purchasely"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "11.0" }
  s.source       = { :git => "https://github.com/Purchasely/Purchasely-ReactNative.git", :tag => "#{s.version}" }

  s.ios.deployment_target = '11.0'
  s.tvos.deployment_target = '11.0'

  s.source_files = "ios/**/*.{h,m,mm,swift}"
  s.requires_arc = true

  s.dependency "React-Core"
  s.dependency "Purchasely", '3.2.2'
end
