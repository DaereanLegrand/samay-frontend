#!/usr/bin/env ruby
# frozen_string_literal: true

# Transient iOS STORE signing patch (mirrors the fastlane adhoc lane's
# `patch_signing_for_build`). The tracked ios/Runner.xcodeproj/project.pbxproj
# keeps the §3.3 placeholders (DEVELOPMENT_TEAM = XXXXXXXXXX, Manual style, empty
# profile specifier) so no team/cert material is committed. An archive that
# relies on those placeholders lets Xcode auto-resolve a profile by bundle id,
# which can land on a stale profile lacking the app's capabilities
# ("requires a provisioning profile with the Push Notifications and Sign In with
# Apple features"). `make build ENV=prod TARGET=ios` therefore patches the REAL
# team + the App Store profile's specifier + the distribution identity for the
# archive, and the Makefile restores the placeholders on exit.
#
# Usage:
#   bundle exec ruby tools/ios_store_signing.rb apply <TEAM> <PROFILE_NAME>
#   bundle exec ruby tools/ios_store_signing.rb restore <BACKUP_PBXPROJ>
require "fileutils"
require "xcodeproj"

PROJECT = "ios/Runner.xcodeproj"

def patch(team, profile_name)
  project = Xcodeproj::Project.open(PROJECT)
  target = project.targets.find { |t| t.name == "Runner" }
  abort "Runner target not found in #{PROJECT}" unless target
  target.build_configurations.each do |config|
    config.build_settings["DEVELOPMENT_TEAM"] = team
    config.build_settings["DEVELOPMENT_TEAM[sdk=iphoneos*]"] = team
    config.build_settings["CODE_SIGN_STYLE"] = "Manual"
    config.build_settings["CODE_SIGN_IDENTITY"] = "Apple Distribution"
    config.build_settings["CODE_SIGN_IDENTITY[sdk=iphoneos*]"] = "Apple Distribution"
    config.build_settings["PROVISIONING_PROFILE_SPECIFIER"] = profile_name
    config.build_settings["PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]"] = profile_name
  end
  project.save
  puts "patched #{PROJECT} with store signing (team #{team}, profile #{profile_name})"
end

def restore(backup)
  abort "backup pbxproj not found: #{backup}" unless File.exist?(backup)
  FileUtils.cp(backup, "#{PROJECT}/project.pbxproj")
  puts "restored #{PROJECT}/project.pbxproj from #{backup}"
end

case ARGV[0]
when "apply"
  team = ARGV[1].to_s
  profile = ARGV[2].to_s
  if team.empty? || team == "XXXXXXXXXX" || profile.empty?
    abort "usage: ios_store_signing.rb apply <TEAM> <PROFILE_NAME>"
  end
  patch(team, profile)
when "restore"
  restore(ARGV[1].to_s)
else
  abort "usage: ios_store_signing.rb apply <TEAM> <PROFILE_NAME> | restore <BACKUP_PBXPROJ>"
end
