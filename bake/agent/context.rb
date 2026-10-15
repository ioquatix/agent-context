# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require_relative "../../lib/agent/context/installer"

include Agent::Context

def initialize(context)
	super(context)
	
	@installer = Installer.new(root: context.root)
end

attr :installer

# List providers and their context definitions, including skills.
# @parameter gem [String | Nil] An optional provider gem.
def list(gem: nil)
	if gem
		provider = @installer.find_provider(gem)
		if provider && !provider.definitions.empty?
			puts "Context files for gem '#{gem}':"
			provider.definitions.each do |definition|
				puts "  #{definition.display_name}"
			end
		else
			puts "No context found for gem '#{gem}'"
		end
	else
		gems = @installer.providers.reject{|provider| provider.definitions.empty?}
		if gems.any?
			puts "Gems with context available:"
			gems.each do |provider|
				puts "  #{provider.name} (#{provider.version})"
			end
		else
			puts "No gems with context found"
		end
	end
end

# Show one context definition from a provider.
# @parameter gem [String] The gem name.
# @parameter file [String] The source filename or skill name.
def show(gem:, file:)
	content = @installer.show_context_file(gem, file)
	if content
		puts content
	else
		puts "Context file '#{file}' not found in gem '#{gem}'"
	end
end

# Install ordinary context and skills.
# @parameter gem [String | Nil] An optional provider gem.
def install(gem: nil)
	installed = @installer.install(gem: gem)
	puts "Installed context from: #{installed[:context].join(", ")}" unless installed[:context].empty?
	puts "Installed skills: #{installed[:skills].join(", ")}" unless installed[:skills].empty?
end
