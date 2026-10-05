#!/usr/bin/env ruby
# frozen_string_literal: true

# Transient iOS development signing patch (opt-008 §3.3 contract).
#
# The tracked ios/Runner.xcodeproj/project.pbxproj keeps signing PLACEHOLDERS
# (DEVELOPMENT_TEAM = XXXXXXXXXX, Manual style, empty profile specifier) so no
# team/cert material is committed (fastlane's adhoc lane patches + restores the
# same way). `flutter run` on a physical iPhone needs REAL signing, so the
# Makefile's `dev TARGET=ios` branch does:
#
#   backup pbxproj → apply (Automatic signing + the .env.local team)
#   → flutter run → restore the backup on exit (trap)
#
# Usage:
#   bundle exec ruby tools/ios_dev_signing.rb apply <TEAM>
#   bundle exec ruby tools/ios_dev_signing.rb restore <BACKUP_PBXPROJ>
require "fileutils"
require "xcodeproj"

PROJECT = "ios/Runner.xcodeproj"

def patch(team)
  project = Xcodeproj::Project.open(PROJECT)
  target = project.targets.find { |t| t.name == "Runner" }
  abort "Runner target not found in #{PROJECT}" unless target
  target.build_configurations.each do |config|
    config.build_settings["DEVELOPMENT_TEAM"] = team
    config.build_settings["DEVELOPMENT_TEAM[sdk=iphoneos*]"] = team
    config.build_settings["CODE_SIGN_STYLE"] = "Automatic"
    config.build_settings["CODE_SIGN_IDENTITY"] = "Apple Development"
    config.build_settings["CODE_SIGN_IDENTITY[sdk=iphoneos*]"] = "Apple Development"
    config.build_settings["PROVISIONING_PROFILE_SPECIFIER"] = ""
    config.build_settings.delete("PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]")
  end
  project.save
  puts "patched #{PROJECT} with Automatic signing (team #{team})"
end

def restore(backup)
  abort "backup pbxproj not found: #{backup}" unless File.exist?(backup)
  FileUtils.cp(backup, "#{PROJECT}/project.pbxproj")
  puts "restored #{PROJECT}/project.pbxproj from #{backup}"
end

case ARGV[0]
when "apply"
  team = ARGV[1].to_s
  abort "usage: ios_dev_signing.rb apply <TEAM>" if team.empty? || team == "XXXXXXXXXX"
  patch(team)
when "restore"
  restore(ARGV[1].to_s)
else
  abort "usage: ios_dev_signing.rb apply <TEAM> | restore <BACKUP_PBXPROJ>"
end
