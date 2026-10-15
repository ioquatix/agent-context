# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "fileutils"
require_relative "../definition"
require_relative "../errors"
require_relative "ownership"

module Agent
	module Context
		module Skills
			# Represents a dependency skill declared by a context document and its resources.
			class Definition < Agent::Context::Definition
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
							raise InvalidError, "Skill resources must be a regular directory: #{assets}"
						end
					else
						assets = nil
					end
					
					installation_content = source.render(frontmatter)
					
					new(source, specification, installed_name, frontmatter["description"], assets, installation_content)
				end
				
				# Validate an installed directory name.
				def self.validate_name(name, file)
					unless name.is_a?(String) && name.match?(Ownership::NAME_PATTERN) && name.length <= 64
						raise InvalidError, "Invalid skill name in #{file}: #{name.inspect}"
					end
				end
				
				# Validate the required authored skill fields.
				def self.validate_metadata(frontmatter, file)
					validate_name(frontmatter["name"], file)
					
					description = frontmatter["description"]
					unless description.is_a?(String)
						raise InvalidError, "Invalid skill description in #{file}"
					end
					
					description = description.strip
					if description.empty? || description.length > 1024
						raise InvalidError, "Invalid skill description in #{file}"
					end
				end
				
				# Retain the source document, specification, and prepared skill instructions.
				def initialize(document, specification, name, description, resources, installation_content)
					super(File.basename(document.path), document.path, document)
					@specification = specification
					@name = name
					@description = description
					@resources = resources
					@installation_content = installation_content
				end
				
				# @attribute [Gem::Specification] The resolved package specification.
				attr_reader :specification
				
				# @attribute [String] The installed skill name.
				attr_reader :name
				
				# @attribute [String] When to use the skill.
				attr_reader :description
				
				# @attribute [String | Nil] The companion resource directory.
				attr_reader :resources
				
				# @attribute [String] The generated instructions with resolved provenance.
				attr_reader :installation_content
				
				# Whether this definition installs as an Agent Skill.
				# @returns [bool] `true` for skill definitions.
				def skill?
					true
				end
				
				# Return the filename shown by the context list with its skill marker.
				# @returns [String] The source filename and skill marker.
				def display_name
					"#{File.basename(@path, File.extname(@path))} (skill)"
				end
				
				# Write instructions before resources so ownership is available during refresh.
				# @parameter destination [String] The installed skill directory.
				def install(destination)
					FileUtils.mkdir_p(destination)
					begin
						File.write(File.join(destination, "SKILL.md"), @installation_content)
					rescue
						FileUtils.rm_rf(destination)
						raise
					end
					copy_resources(@resources, destination, true) if @resources
				end
				
				private
				
				def copy_resources(source, destination, top_level)
					Dir.children(source).sort.each do |name|
						from = File.join(source, name)
						to = File.join(destination, name)
						metadata = File.lstat(from)
						
						if metadata.symlink? || (!metadata.file? && !metadata.directory?)
							raise InvalidError, "Skill resources must be regular files or directories: #{from}"
						end
						
						if top_level && name.downcase == "skill.md"
							raise InvalidError, "#{name} is reserved for generated skill files: #{from}"
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
