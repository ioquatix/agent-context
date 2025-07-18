# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

source "https://rubygems.org"

gemspec

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	
	gem "utopia-project"
end

group :test do
	gem "sus"
	gem "covered"
	gem "decode"
	gem "rubocop"
	
	gem "sus-fixtures-console"
	
	gem "bake-test"
end
