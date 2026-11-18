# Adds the Purchasely iOS SDK to the react-native-purchasely pod through Swift Package
# Manager during `pod install`. Clients change nothing in their Podfile or Xcode project.
#
# The podspec requires this file, which wraps two private Pod::Installer methods (the same
# approach as stripe-react-native and react-native-firebase):
#
# run_podfile_post_install_hooks (Pods.xcodeproj, in memory, before CocoaPods saves it):
#   1. guard_uuid_counter: stops new objects from overwriting existing ones (see below).
#   2. The Podfile post_install hooks. React Native's react_native_post_install removes every
#      Swift package reference, then adds back the ones that its spm_dependency declared.
#   3. add_package: adds the local package ios/PurchaselySPM and its Purchasely product to the
#      react-native-purchasely target. It runs after step 2, so React Native does not remove
#      it, and it removes no other reference. It does not use spm_dependency: React Native
#      0.75-0.83 makes a remote reference from a local path.
#   4. verify_pods_project!: stops the install before CocoaPods saves a damaged project.
#
# run_podfile_post_integrate_hooks (the client .xcodeproj): add_embed_phase. Xcode embeds a
# package framework only in the targets that link it directly, so without this phase the app
# crashes at launch: "Library not loaded: @rpath/Purchasely.framework/Purchasely".
require 'pathname'

module PurchaselySPM
  POD_NAME = 'react-native-purchasely'.freeze
  PRODUCT = 'Purchasely'.freeze
  PACKAGE_PATH = File.expand_path('PurchaselySPM', __dir__).freeze
  # CocoaPods 1.13 is the first release that requires Xcodeproj 1.23 (local Swift packages).
  MINIMUM_COCOAPODS = '1.13.0'.freeze
  PHASE_NAME = '[react-native-purchasely] Embed Purchasely.framework'.freeze

  SCRIPT = <<~'SCRIPT'.freeze
    set -e
    [ -n "${TARGET_BUILD_DIR:-}" ] && [ -n "${FRAMEWORKS_FOLDER_PATH:-}" ] || exit 0
    # The bridge pod was removed: do not copy a stale framework from DerivedData. CocoaPods can
    # suffix the label (react-native-purchasely-iOS), so match the prefix.
    ls -d "${PODS_ROOT:-}/Target Support Files/react-native-purchasely"* >/dev/null 2>&1 || exit 0
    # Xcode stages the binary target signature once per consumer; a second copy fails Archive.
    rm -f "${CONFIGURATION_BUILD_DIR}/Purchasely.xcframework-ios.signature"
    for SRC in "${BUILT_PRODUCTS_DIR}/Purchasely.framework" "${OBJROOT}/UninstalledProducts/${PLATFORM_NAME}/Purchasely.framework"; do
      [ -f "$SRC/Purchasely" ] || continue
      DEST="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      mkdir -p "$DEST"
      rsync -a --delete --exclude Headers --exclude Modules "$SRC" "$DEST/"
      if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ] && [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
        codesign --force --sign "$EXPANDED_CODE_SIGN_IDENTITY" ${OTHER_CODE_SIGN_FLAGS:-} --preserve-metadata=identifier,entitlements "$DEST/Purchasely.framework"
      fi
      exit 0
    done
    echo "warning: [react-native-purchasely] Purchasely.framework not found in ${BUILT_PRODUCTS_DIR}; the app will not launch" >&2
  SCRIPT

  def self.hookable?(installer_class)
    %i[run_podfile_post_install_hooks run_podfile_post_integrate_hooks].all? do |name|
      installer_class.method_defined?(name) || installer_class.private_method_defined?(name)
    end && defined?(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
  end

  def self.unsupported_cocoapods!
    error = defined?(Pod::PlainInformative) ? Pod::PlainInformative : RuntimeError
    raise error, "[react-native-purchasely] This CocoaPods (#{defined?(Pod::VERSION) ? Pod::VERSION : 'unknown'}) " \
                 'cannot add the Purchasely iOS SDK through Swift Package Manager. ' \
                 "Update CocoaPods to #{MINIMUM_COCOAPODS} or later. " \
                 'If your CocoaPods is already 1.13.0 or later, report this version to Purchasely.'
  end

  # The Pods projects that hold a react-native-purchasely target, with those targets. With
  # generate_multiple_pod_projects, the target is in a subproject, not in installer.pods_project.
  def self.bridge_targets_by_project(installer)
    labels = installer.pod_targets.select { |t| t.pod_name == POD_NAME }.map(&:label)
    projects = installer.generated_projects || [installer.pods_project]
    projects.compact.to_h { |p| [p, p.targets.select { |t| labels.include?(t.name) }] }.reject { |_, t| t.empty? }
  end

  # Copied from stripe-react-native (MIT), stripe_spm.rb at 33ef1ee27a:
  # ensure_uuid_counter_safe and verify_pods_project_integrity!.
  # CocoaPods mints Pods-project UUIDs from a counter (6-char prefix, 7 hex digits, '0') with no
  # collision check. When the project is not freshly generated (incremental installation), the
  # counter restarts near zero and project.new can overwrite an existing object, for example the
  # root PBXProject. This raises the counter past every counter-format UUID in the project. It
  # also protects React Native's own spm_dependency writes, which come before ours.
  def self.guard_uuid_counter(installer)
    bridge_targets_by_project(installer).each_key do |project|
      prefix = project.instance_variable_get(:@uuid_prefix)
      next unless prefix.is_a?(String) && prefix.length >= 6

      max_index = -1
      project.objects_by_uuid.each_key do |uuid|
        next unless uuid.is_a?(String) && uuid.length == 14 && uuid.start_with?(prefix[0, 6]) && uuid.end_with?('0')

        max_index = [max_index, uuid[6, 7].to_i(16)].max
      end
      next if max_index < 0

      generated = project.instance_variable_get(:@generated_uuids)
      generated = [] unless generated.is_a?(Array)
      raised = generated.size <= max_index
      generated << format('%.6s%07X0', prefix, generated.size) while generated.size <= max_index
      project.instance_variable_set(:@generated_uuids, generated)
      project.instance_variable_set(:@available_uuids, [])
      Pod::UI.puts "[react-native-purchasely] Raised the UUID counter of #{File.basename(project.path)} past index #{max_index}" if raised
    end
  end

  def self.add_package(installer)
    bridge_targets_by_project(installer).each do |project, targets|
      refs = project.root_object.package_references
      # Relative to the Pods project folder, so the project does not hold a machine path.
      path = Pathname(PACKAGE_PATH).relative_path_from(Pathname(project.path).dirname).to_s
      pkg = refs.find { |p| p.is_a?(Xcodeproj::Project::Object::XCLocalSwiftPackageReference) && p.relative_path == path }
      unless pkg
        pkg = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
        pkg.relative_path = path
        refs << pkg
      end
      targets.each do |target|
        dep = target.package_product_dependencies.find { |d| d.product_name == PRODUCT }
        unless dep
          dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
          dep.product_name = PRODUCT
          target.package_product_dependencies << dep
        end
        dep.package = pkg
      end
    end
  end

  def self.verify_pods_project!(installer)
    bridge_targets_by_project(installer).each_key do |project|
      root = project.root_object
      resolved = root && project.objects_by_uuid[root.uuid]
      next if resolved.equal?(root) && resolved.isa == 'PBXProject'

      raise Pod::Informative, "[react-native-purchasely] #{File.basename(project.path)} failed an integrity check, " \
                              'and Xcode cannot open it. Delete ios/Pods, then run pod install again.'
    end
  end

  def self.add_embed_phase(installer)
    installer.aggregate_targets.each do |aggregate|
      project = aggregate.user_project
      next unless project && aggregate.pod_targets.any? { |t| t.pod_name == POD_NAME }

      changed = false
      aggregate.user_targets.each do |target|
        next unless target.symbol_type == :application

        phase = target.shell_script_build_phases.find { |p| p.name == PHASE_NAME }
        next if phase && phase.shell_script == SCRIPT

        phase ||= target.new_shell_script_build_phase(PHASE_NAME)
        phase.shell_path = '/bin/sh'
        phase.shell_script = SCRIPT
        phase.always_out_of_date = '1'
        changed = true
      end
      project.save if changed
    end
  end
end

# No CocoaPods install is running (plain Ruby): nothing to do.
if defined?(Pod::Installer)
  installer_class = Pod::Installer
  PurchaselySPM.unsupported_cocoapods! unless PurchaselySPM.hookable?(installer_class)

  # The originals are private; alias_method keeps that, so check both visibilities.
  unless installer_class.private_method_defined?(:purchasely_spm_post_install) ||
         installer_class.method_defined?(:purchasely_spm_post_install)
    installer_class.class_eval do
      alias_method :purchasely_spm_post_install, :run_podfile_post_install_hooks
      define_method(:run_podfile_post_install_hooks) do
        begin
          PurchaselySPM.guard_uuid_counter(self)
        rescue StandardError => e
          Pod::UI.warn "[react-native-purchasely] Could not guard the Pods project UUID counter (#{e.class}: #{e.message})"
        end
        result = purchasely_spm_post_install
        PurchaselySPM.add_package(self)
        PurchaselySPM.verify_pods_project!(self)
        result
      end

      alias_method :purchasely_spm_post_integrate, :run_podfile_post_integrate_hooks
      define_method(:run_podfile_post_integrate_hooks) do
        PurchaselySPM.add_embed_phase(self)
        purchasely_spm_post_integrate
      end
      private :run_podfile_post_install_hooks, :purchasely_spm_post_install,
              :run_podfile_post_integrate_hooks, :purchasely_spm_post_integrate
    end
  end
end
