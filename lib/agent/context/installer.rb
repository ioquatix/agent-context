# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025-2026, by Shopify Inc.
# Copyright, 2025-2026, by Samuel Williams.

require "rubygems"
require "fileutils"

require_relative "paths"
require_relative "errors"
require_relative "skills/ownership"
require_relative "skills/definition"
require_relative "exclusion"
require_relative "package"

module Agent
	module Context
		# Discovers, lists, reads, and installs context from resolved Ruby gems.
		class Installer
			# Retain the consuming project and gem specifications.
			def initialize(root: Dir.pwd, specifications: ::Gem::Specification)
				@root = File.expand_path(root)
				@context_path = File.join(@root, CONTEXT_PATH)
				@specifications = specifications
			end
			
			attr_reader :root
			attr_reader :context_path
			
			# Load providers with a context directory, including empty providers.
			def providers(skip_local: true)
				packages(skip_local: skip_local)
			end
			
			# Load one provider by its gem name.
			def find_provider(name)
				packages(gem: name).first
			end
			
			# Read the authored content of a selected definition.
			def show_context_file(gem_name, file_name)
				find_provider(gem_name)&.find_definition(file_name)&.content
			end
			
			# Install all selected definitions and reconcile dependency-owned skills.
			def install(gem: nil)
				# Resolve providers and load every definition once:
				selected = packages(gem: gem)
				raise Error, "No context found for gem: #{gem}" if gem && selected.empty?
				definitions = selected.flat_map(&:definitions)
				skills = definitions.grep(Skills::Definition)
				
				# Apply the skill-specific destination and ownership rules:
				installed_skills = install_skills(skills, package: gem)
				
				# Refresh ordinary files from the same loaded definitions:
				installed_context = selected.filter_map do |package|
					package.name if package.install_files(File.join(@context_path, package.name))
				end
				
				{context: installed_context, skills: installed_skills}
			end
			
			private
			
			def packages(gem: nil, skip_local: true)
				specifications = @specifications.select do |specification|
					gem ? specification.name == gem : !skip_local || File.expand_path(specification.full_gem_path) != @root
				end
				if gem && specifications.length > 1
					raise ConflictError, "Multiple resolved versions provide gem #{gem.inspect}"
				end
				
				specifications.filter_map{|specification| Package.load(specification)}
			end
			
			def install_skills(definitions, package:)
				# Validate selected names and ownership before writing any skill:
				duplicates = definitions.group_by(&:name).select{|_name, matches| matches.length > 1}
				raise ConflictError, "Multiple providers supply skills: #{duplicates.keys.join(", ")}" unless duplicates.empty?
				
				skills_path = File.join(@root, ".agents", "skills")
				owners = Skills::Ownership.scan(skills_path)
				validate_skill_destinations(definitions, skills_path, owners)
				
				names = definitions.map(&:name)
				owned = owners.select do |_name, owner|
					owner["ecosystem"] == "gem" && (!package || owner["package"] == package)
				end
				stale = owned.keys - names
				
				# Refresh selected skills, then remove stale entries in this scope:
				FileUtils.mkdir_p(skills_path) unless definitions.empty? && stale.empty?
				definitions.each do |definition|
					destination = File.join(skills_path, definition.name)
					FileUtils.rm_rf(destination)
					definition.install(destination)
				end
				stale.each{|name| FileUtils.rm_rf(File.join(skills_path, name))}
				
				# Keep local Git exclusions aligned with the remaining installed skills:
				Exclusion.prepare(@root, (owners.keys - stale + names).uniq)&.apply
				names
			end
			
			def validate_skill_destinations(definitions, skills_path, owners)
				definitions.each do |definition|
					owner = owners[definition.name]
					destination = File.join(skills_path, definition.name)
					
					if owner && owner.values_at("ecosystem", "package") != ["gem", definition.specification.name]
						raise ConflictError, "Skill #{definition.name.inspect} belongs to #{owner["ecosystem"]}:#{owner["package"]}"
					end
					
					if (File.exist?(destination) || File.symlink?(destination)) && !owner
						raise ConflictError, "Skill #{definition.name.inspect} is not managed by Agent Context"
					end
				end
			end
		end
	end
end
