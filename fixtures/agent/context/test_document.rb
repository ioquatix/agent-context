# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

module Agent
	module Context
		# Provides the skill document shared by parsing and ownership tests.
		module TestDocument
			# @returns [String] The path to the shared skill document.
			def self.path
				File.expand_path("test_document/SKILL.md", __dir__)
			end
		end
	end
end
