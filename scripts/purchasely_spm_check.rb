# Checks for packages/purchasely/ios/purchasely_spm.rb.
# Usage: ruby scripts/purchasely_spm_check.rb <path to purchasely_spm.rb> missing|ok|plain|guard
# missing: Pod::Installer without run_podfile_post_integrate_hooks -> clear compatibility error.
# ok:      both hooks present -> wrapped once after two loads, originals run once, hooks private.
# plain:   no Pod::Installer -> loads with no error and no hook.
# guard:   needs the cocoapods gem. A Pod::Project whose UUID counter restarts at 0 must not get
#          its root object overwritten by our package reference.
file, mode = ARGV
abort "FAIL: #{file} does not exist" unless file && File.exist?(file)

if mode == 'guard'
  require 'cocoapods'
  require 'tmpdir'
  load file
  run = lambda do |guarded|
    project = Pod::Project.new(File.join(Dir.tmpdir, 'react-native-purchasely.xcodeproj'))
    target = project.new_target(:static_library, 'react-native-purchasely', :ios, '15.1')
    root = project.root_object
    project.instance_variable_set(:@generated_uuids, [])
    project.instance_variable_set(:@available_uuids, [])
    pod_target = Struct.new(:pod_name, :label).new('react-native-purchasely', target.name)
    installer = Struct.new(:pod_targets, :generated_projects, :pods_project).new([pod_target], [project], project)
    PurchaselySPM.guard_uuid_counter(installer) if guarded
    PurchaselySPM.add_package(installer)
    root_ok = project.objects_by_uuid[root.uuid].equal?(root)
    verified = begin
      PurchaselySPM.verify_pods_project!(installer)
      true
    rescue Pod::Informative
      false
    end
    [root_ok, verified]
  end
  abort 'FAIL: without the guard the counter reset does not collide, the check proves nothing' if run.call(false) == [true, true]
  abort 'FAIL: with the guard the root object is overwritten or the integrity check raises' unless run.call(true) == [true, true]
  puts 'PASS guard: collision without the guard, none with it'
  exit
end

module Xcodeproj; class Project; module Object; class XCLocalSwiftPackageReference; end; end; end; end
module Pod
  VERSION = '1.9.3'.freeze
  class PlainInformative < StandardError; end
  module UI; def self.puts(*); end; def self.warn(*); end; end
end
case mode
when 'missing'
  Pod.const_set(:Installer, Class.new { private def run_podfile_post_install_hooks; end })
  begin
    load file
    abort 'FAIL: no error'
  rescue Pod::PlainInformative => e
    abort "FAIL: #{e.message}" unless e.message.include?('Update CocoaPods to 1.13.0 or later')
    puts "PASS missing: #{e.message}"
  end
when 'ok'
  calls = []
  Pod.const_set(:Installer, Class.new do
    define_method(:pod_targets) { [] }
    define_method(:aggregate_targets) { [] }
    define_method(:pods_project) { nil }
    define_method(:generated_projects) { nil }
    private define_method(:run_podfile_post_install_hooks) { calls << :post_install }
    private define_method(:run_podfile_post_integrate_hooks) { calls << :post_integrate }
  end)
  load file
  load file
  i = Pod::Installer.new
  i.send(:run_podfile_post_install_hooks)
  i.send(:run_podfile_post_integrate_hooks)
  abort "FAIL calls #{calls}" unless calls == %i[post_install post_integrate]
  abort 'FAIL visibility' unless Pod::Installer.private_method_defined?(:run_podfile_post_install_hooks) &&
                                 Pod::Installer.private_method_defined?(:run_podfile_post_integrate_hooks)
  puts "PASS ok: originals ran once each #{calls}, hooks private"
when 'plain'
  load file
  abort 'FAIL' if defined?(Pod::Installer)
  puts 'PASS plain: loaded without CocoaPods installer'
else
  abort "FAIL: unknown mode #{mode.inspect}"
end
