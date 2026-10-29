# Usage: ruby count-embed-phases.rb <App.xcodeproj>
# Prints "<target>: <n>" per app target: n is the number of Purchasely embed phases.
require 'xcodeproj'

Xcodeproj::Project.open(ARGV.fetch(0)).targets.select { |t| t.symbol_type == :application }.each do |t|
  puts "#{t.name}: #{t.shell_script_build_phases.count { |p| p.name == '[react-native-purchasely] Embed Purchasely.framework' }}"
end
