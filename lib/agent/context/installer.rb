# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025-2026, by Samuel Williams.

require "rubygems"
require "pathname"
require_relative "paths"
require_relative "skills/installer"
require_relative "package"

module Agent
	module Context
		# Represents discovery and installation of context from resolved Ruby gems.
		class Installer
			# Retain the consuming project and gem specifications.
			def initialize(root: Dir.pwd, specifications: ::Gem::Specification)
				@root = File.expand_path(root)
				@context_path = File.join(@root, CONTEXT_PATH)
				@specifications = specifications
			end
			
			# @attribute [String] The consuming project root.
			attr_reader :root
			
			# @attribute [String] The installed context directory.
			attr_reader :context_path
			
			# Find providers with ordinary context.
			def find_gems_with_context(skip_local: true)
				packages(skip_local: skip_local).reject{|package| package.files.empty?}.map(&:information)
			end
			
			# Find one provider with ordinary context.
			def find_gem_with_context(gem_name)
				package = packages(gem: gem_name).first
				package.information if package && !package.files.empty?
			end
			
			# List a provider's ordinary context paths.
			def list_context_files(gem_name)
				package = packages(gem: gem_name).first
				package.files.keys if package && !package.files.empty?
			end
			
			# Read a selected ordinary context document or resource.
			def show_context_file(gem_name, file_name)
				# Resolve the requested path within the loaded provider files:
				requested = Pathname.new(file_name)
				if requested.absolute? || requested.each_filename.any?{|part| part == ".."}
					raise ArgumentError, "Context file must be a relative path inside context/"
				end
				
				package = packages(gem: gem_name).first
				return unless package
				candidates = [File.join(package.path, file_name)]
				candidates << "#{candidates.first}.md" if File.extname(file_name).empty?
				path = candidates.find{|candidate| package.files.key?(candidate)}
				return unless path
				
				# Return loaded Markdown or read the selected opaque resource:
				package.files[path]&.content || File.read(path)
			end
			
			# Refresh ordinary context for one provider.
			def install_gem_context(gem_name)
				package = packages(gem: gem_name).first
				package ? package.install(File.join(@context_path, package.name)) : false
			end
			
			# Refresh ordinary context for all selected providers.
			def install_all_context(skip_local: true)
				packages(skip_local: skip_local).filter_map do |package|
					package.name if package.install(File.join(@context_path, package.name))
				end
			end
			
			# Install context and skills from the same loaded provider documents.
			def install(gem: nil)
				# Resolve providers and parse their documents once:
				selected = packages(gem: gem)
				raise Skills::Installer::Error, "No gem found: #{gem}" if gem && selected.empty?
				definitions = selected.flat_map(&:skills)
				
				# Refresh skills and ordinary context using that loaded representation:
				skills = Skills::Installer.new(root: @root, specifications: @specifications)
				installed_skills = skills.install_definitions(definitions, package: gem, reconcile: true)
				installed_context = selected.filter_map do |package|
					package.name if package.install(File.join(@context_path, package.name))
				end
				{context: installed_context, skills: installed_skills}
			end
			
			private
			
			def packages(gem: nil, skip_local: true)
				specifications = @specifications.select do |specification|
					gem ? specification.name == gem : !skip_local || File.expand_path(specification.full_gem_path) != @root
				end
				if gem && specifications.length > 1
					raise Skills::Installer::Conflict, "Multiple resolved versions provide gem #{gem.inspect}"
				end
				
				specifications.map{|specification| Package.load(specification)}
			end
		end
	end
end
