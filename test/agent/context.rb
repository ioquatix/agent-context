# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

describe Agent::Context do
	it "has a version number" do
		expect(Agent::Context::VERSION).to be =~ /^\d+\.\d+\.\d+$/
	end
end 
