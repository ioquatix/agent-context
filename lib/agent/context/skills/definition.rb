# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require "fileutils"
require_relative "ownership"

module Agent
	module Context
		module Skills
			# Represents a dependency skill declared by a context document and its resources.
			class Definition
				# Build instructions from a parsed skill document and its provider.
				def self.from_document(source, specification)
					# Preserve authored names and derive missing names from the provider and file:
					file = source.path
					local_name = File.basename(file, File.extname(file))
					installed_name = source.frontmatter.fetch("name"){"#{specification.name.downcase.tr("_", "-")}-#{local_name}"}
					
					# Add the resolved provider identity to the authored front matter:
					frontmatter = source.frontmatter.merge("name" => installed_name)
					frontmatter["metadata"] = source.metadata.merge(
						"ecosystem" => "gem",
						"package" => specification.name,
						"version" => specification.version.to_s,
					)
					validate_metadata(frontmatter, file)
					
					# Resolve resources using the source filename:
					assets = File.join(File.dirname(file), local_name)
					if File.exist?(assets) || File.symlink?(assets)
						unless File.lstat(assets).directory?
							raise Installer::InvalidSkill, "Skill resources must be a regular directory: #{assets}"
						end
					else
						assets = nil
					end
					
					document = source.render(frontmatter)
					
					new(
						name: installed_name,
						description: frontmatter["description"],
						path: assets,
						source_file: file,
						document: document,
						provider_name: specification.name,
						provider_version: specification.version.to_s,
					)
				end
				
				# Validate an installed directory name.
				def self.validate_name(name, file)
					unless name.is_a?(String) && name.match?(Ownership::NAME_PATTERN) && name.length <= 64
						raise Installer::InvalidSkill, "Invalid skill name in #{file}: #{name.inspect}"
					end
				end
				
				# Validate the required authored skill fields.
				def self.validate_metadata(frontmatter, file)
					validate_name(frontmatter["name"], file)
					
					description = frontmatter["description"]
					unless description.is_a?(String)
						raise Installer::InvalidSkill, "Invalid skill description in #{file}"
					end
					
					description = description.strip
					if description.empty? || description.length > 1024
						raise Installer::InvalidSkill, "Invalid skill description in #{file}"
					end
				end
				
				# Initialize a skill from a context document.
				# @parameter name [String] The installed skill name.
				# @parameter description [String] When to use the skill.
				# @parameter path [String | Nil] The companion resource directory.
				# @parameter provider_name [String] The provider gem.
				# @parameter provider_version [String] The provider version.
				# @parameter source_file [String] The source context document.
				# @parameter document [String] Generated skill instructions.
				def initialize(
					name:, description:, path:,
					provider_name:, provider_version:,
					source_file:, document:
				)
					@name = name
					@description = description
					@path = path
					@provider_name = provider_name
					@provider_version = provider_version
					@source_file = source_file
					@document = document
				end
				
				# @attribute [String] The installed skill name.
				attr_reader :name
				
				# @attribute [String] When to use the skill.
				attr_reader :description
				
				# @attribute [String | Nil] The companion resource directory.
				attr_reader :path
				
				# @attribute [String] The provider gem.
				attr_reader :provider_name
				
				# @attribute [String] The provider version.
				attr_reader :provider_version
				
				# @attribute [String] The source context document.
				attr_reader :source_file
				
				# @returns [String] The installed skill instructions.
				def content
					@document
				end
				
				# Write instructions before resources so ownership is available during refresh.
				# @parameter destination [String] The installed skill directory.
				def write_to(destination)
					FileUtils.mkdir_p(destination)
					begin
						File.write(File.join(destination, "SKILL.md"), @document)
					rescue
						FileUtils.rm_rf(destination)
						raise
					end
					copy_resources(@path, destination, true) if @path
				end
				
				private
				
				def copy_resources(source, destination, top_level)
					Dir.children(source).sort.each do |name|
						from = File.join(source, name)
						to = File.join(destination, name)
						metadata = File.lstat(from)
						
						if metadata.symlink? || (!metadata.file? && !metadata.directory?)
							raise Installer::InvalidSkill, "Skill resources must be regular files or directories: #{from}"
						end
						
						if top_level && name.downcase == "skill.md"
							raise Installer::InvalidSkill, "#{name} is reserved for generated skill files: #{from}"
						end
						
						if metadata.directory?
							FileUtils.mkdir_p(to)
							copy_resources(from, to, false)
						else
							FileUtils.copy_file(from, to, true)
						end
					end
				end
			end
		end
	end
end
