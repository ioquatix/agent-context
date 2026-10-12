# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "fileutils"
require "rubygems"
require "yaml"

require_relative "definition"
require_relative "ownership"
require_relative "../exclusion"
require_relative "../package"

module Agent
	module Context
		module Skills
			# Represents discovery and installation of skills from resolved gems.
			class Installer
				NAME_PATTERN = Ownership::NAME_PATTERN
				
				# Raised when a skill cannot be installed.
				class Error < StandardError
				end
				
				# Raised when skill metadata or resources are invalid.
				class InvalidSkill < Error
				end
				
				# Raised when a destination has ambiguous or foreign ownership.
				class Conflict < Error
				end
				
				# Initialize discovery from the project's gem specifications.
				# @parameter root [String] The consuming project root.
				# @parameter specifications [Enumerable] The resolved gem specifications.
				def initialize(root: Dir.pwd, specifications: ::Gem::Specification)
					@root = File.expand_path(root)
					@skills_path = File.join(@root, ".agents", "skills")
					@specifications = specifications
				end
				
				# @attribute [String] The consuming project root.
				attr_reader :root
				
				# @attribute [String] The installed skill directory.
				attr_reader :skills_path
				
				# Find skill providers.
				# @parameter skip_local [bool] Whether to exclude the consuming gem.
				# @returns [Array(Hash)] The discovered providers.
				def find_gems_with_skills(skip_local: true)
					@specifications.filter_map do |specification|
						next if skip_local && File.expand_path(specification.full_gem_path) == @root
						
						information = build_gem_information(specification)
						information unless information[:skills].empty?
					end
				end
				
				# Find a skill provider by gem name.
				# @parameter gem_name [String] The provider gem.
				# @returns [Hash | Nil] The discovered provider.
				def find_gem_with_skills(gem_name)
					specification = find_specification(gem_name)
					return unless specification
					
					information = build_gem_information(specification)
					information unless information[:skills].empty?
				end
				
				# List a gem's skills.
				# @parameter gem_name [String] The provider gem.
				# @returns [Array(Definition) | Nil] The provided skills.
				def list_skills(gem_name)
					find_gem_with_skills(gem_name)&.fetch(:skills)
				end
				
				# Read a skill's generated instruction file.
				# @parameter gem_name [String] The provider gem.
				# @parameter skill_name [String] The installed skill name.
				# @returns [String | Nil] The instructions.
				def show_skill(gem_name, skill_name)
					list_skills(gem_name)&.find{|skill| skill.name == skill_name}&.content
				end
				
				# Install selected skills and reconcile only the corresponding ownership scope.
				# @parameter gem [String | Nil] An optional provider gem.
				# @parameter skill [String | Nil] An optional installed skill name.
				# @parameter skip_local [bool] Whether to exclude the consuming gem.
				# @returns [Array(String)] The installed skill names.
				def install(gem: nil, skill: nil, skip_local: true)
					if gem
						specification = find_specification(gem)
						raise Error, "No gem found: #{gem}" unless specification
						providers = [build_gem_information(specification)]
					else
						providers = find_gems_with_skills(skip_local: skip_local)
					end
					
					definitions = providers.flat_map{|provider| provider[:skills]}
					if skill
						definitions.select!{|definition| definition.name == skill}
						raise Error, "No dependency skill found: #{skill}" if definitions.empty?
					end
					
					install_definitions(definitions, package: gem, reconcile: !skill)
				end
				
				# Install prepared definitions and reconcile their ownership scope.
				def install_definitions(definitions, package:, reconcile:)
					duplicates = definitions.group_by(&:name).select{|_name, matches| matches.length > 1}
					raise Conflict, "Multiple providers supply skills: #{duplicates.keys.join(", ")}" unless duplicates.empty?
					
					if File.exist?(@skills_path) || File.symlink?(@skills_path)
						unless File.lstat(@skills_path).directory?
							raise Conflict, "Skill installation path must be a regular directory: #{@skills_path}"
						end
					end
					
					owners = Ownership.scan(@skills_path)
					validate_destinations(definitions, owners)
					
					names = definitions.map(&:name)
					owned = owners.select do |_name, owner|
						owner["ecosystem"] == "gem" && (!package || owner["package"] == package)
					end
					stale = reconcile ? owned.keys - names : []
					
					# Refresh each selected skill from its loaded instructions:
					FileUtils.mkdir_p(@skills_path)
					definitions.each do |definition|
						destination = File.join(@skills_path, definition.name)
						FileUtils.rm_rf(destination)
						definition.write_to(destination)
					end
					
					# Reconcile the requested ownership scope and refresh Git exclusions:
					stale.each{|name| FileUtils.rm_rf(File.join(@skills_path, name))}
					Exclusion.prepare(@root, (owners.keys - stale + names).uniq)&.apply
					names
				end
				
				private
				
				def find_specification(name)
					matches = @specifications.select{|specification| specification.name == name}
					raise Conflict, "Multiple resolved versions provide gem #{name.inspect}" if matches.length > 1
					
					matches.first
				end
				
				def build_gem_information(specification)
					Package.load(specification).information
				end
				
				def validate_destinations(definitions, owners)
					definitions.each do |definition|
						owner = owners[definition.name]
						destination = File.join(@skills_path, definition.name)
						
						if owner && owner.values_at("ecosystem", "package") != ["gem", definition.provider_name]
							raise Conflict, "Skill #{definition.name.inspect} belongs to #{owner["ecosystem"]}:#{owner["package"]}"
						end
						
						if (File.exist?(destination) || File.symlink?(destination)) && !owner
							raise Conflict, "Skill #{definition.name.inspect} is not managed by Agent Context"
						end
					end
				end
				
			end
		end
	end
end
