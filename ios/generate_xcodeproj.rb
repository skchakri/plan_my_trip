#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates ios/PlanMyTrip/PlanMyTrip.xcodeproj from the checked-in Swift
# sources, wiring in the hotwire-native-ios Swift Package. This replaces the
# manual "create a new Xcode project" steps in README.md so the app can be
# built headlessly with xcodebuild.
#
#   gem install xcodeproj   # if not already present
#   ruby ios/generate_xcodeproj.rb
#
# Idempotent: regenerates the .xcodeproj from scratch each run.

require "xcodeproj"
require "fileutils"

ROOT       = File.expand_path(File.join(__dir__, "PlanMyTrip"))
PROJ_PATH  = File.join(ROOT, "PlanMyTrip.xcodeproj")
SRC_DIR    = File.join(ROOT, "PlanMyTrip")
BUNDLE_ID  = "com.wanderply.PlanMyTrip"
DEPLOY_TGT = "16.0"

FileUtils.rm_rf(PROJ_PATH)
project = Xcodeproj::Project.new(PROJ_PATH)

target = project.new_target(:application, "PlanMyTrip", :ios, DEPLOY_TGT)

# Group holding the Swift sources (mirrors the on-disk PlanMyTrip/ subfolder).
group = project.main_group.new_group("PlanMyTrip", "PlanMyTrip")
swift_files = Dir[File.join(SRC_DIR, "*.swift")].sort
swift_files.each do |path|
  ref = group.new_reference(path)
  target.add_file_references([ref])
end
# Keep Info.plist visible in the navigator (not compiled).
group.new_reference(File.join(SRC_DIR, "Info.plist"))

# Asset catalog (app icon) -> resources build phase.
assets = File.join(SRC_DIR, "Assets.xcassets")
if File.directory?(assets)
  assets_ref = group.new_reference(assets)
  target.add_resources([assets_ref])
end

# --- hotwire-native-ios Swift Package -------------------------------------
pkg_ref = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
pkg_ref.repositoryURL = "https://github.com/hotwired/hotwire-native-ios"
pkg_ref.requirement = { "kind" => "upToNextMajorVersion", "minimumVersion" => "1.0.0" }
project.root_object.package_references << pkg_ref

product_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
product_dep.package = pkg_ref
product_dep.product_name = "HotwireNative"
target.package_product_dependencies << product_dep

build_file = project.new(Xcodeproj::Project::Object::PBXBuildFile)
build_file.product_ref = product_dep
target.frameworks_build_phase.files << build_file

# --- Build settings -------------------------------------------------------
target.build_configurations.each do |config|
  s = config.build_settings
  s["PRODUCT_BUNDLE_IDENTIFIER"]       = BUNDLE_ID
  s["PRODUCT_NAME"]                    = "$(TARGET_NAME)"
  s["INFOPLIST_FILE"]                  = "PlanMyTrip/Info.plist"
  s["IPHONEOS_DEPLOYMENT_TARGET"]      = DEPLOY_TGT
  s["SWIFT_VERSION"]                   = "5.0"
  s["TARGETED_DEVICE_FAMILY"]          = "1,2"
  s["GENERATE_INFOPLIST_FILE"]         = "NO"
  # Signing: default off (simulator). Set DEVELOPMENT_TEAM in the environment
  # to produce a signed device archive (automatic signing).
  if (team = ENV["DEVELOPMENT_TEAM"]) && !team.empty?
    s["DEVELOPMENT_TEAM"]              = team
    s["CODE_SIGN_STYLE"]              = "Automatic"
  else
    s["CODE_SIGNING_ALLOWED"]         = "NO" # simulator builds need no signing
    s["CODE_SIGNING_REQUIRED"]        = "NO"
  end
  s["ASSETCATALOG_COMPILER_APPICON_NAME"] = "AppIcon"
  # BASE_URL flows into Info.plist ($(BASE_URL)); blank => AppConfig default.
  s["BASE_URL"] ||= ""
end

project.save
puts "Generated #{PROJ_PATH}"
puts "Sources: #{swift_files.map { |f| File.basename(f) }.join(', ')}"
