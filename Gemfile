# Samay — Ruby dependencies for fastlane + CocoaPods (agent M-17, phase 4.3;
# to-fix MKE-10, the reference app pattern). Bundle only via the Makefile gate:
#
#   make bundle-install     # = bundle install (Gemfile.lock-aware)
#   bundle exec fastlane ios <lane>
#
# NOTE: Gemfile.lock IS committed (M-19 fix: lockfile in version control for
# reproducible builds). Every Ruby invocation goes through `bundle exec` —
# the Makefile fastlane targets and `make bundle-install` already do.
source "https://rubygems.org"

ruby ">= 3.0"

gem "fastlane"
gem "cocoapods"
