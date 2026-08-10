# Samay — Ruby dependencies for fastlane + CocoaPods (agent M-17, phase 4.3;
# to-fix MKE-10, Juega pattern). Bundle only via the Makefile gate:
#
#   make bundle-install     # = bundle install (Gemfile.lock-aware)
#   bundle exec fastlane ios <lane>
#
# NOTE: Gemfile.lock is intentionally NOT committed yet. Generating it
# requires `bundle install` (network + gem resolution), which the M-17 track
# deliberately does not run (no network ops, no gem installs — AGENT-RULES).
# The lockfile is committed by M-19 after the first real `bundle install`
# (MKE-10 fix: lockfile in version control for reproducible builds; every
# Ruby invocation goes through `bundle exec` — the Makefile fastlane targets
# and `make bundle-install` already do).
source "https://rubygems.org"

ruby ">= 3.0"

gem "fastlane"
gem "cocoapods"
