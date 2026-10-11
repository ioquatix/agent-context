# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "markly"
require "yaml"
require "date"

module Agent
	module Context
		# Represents a context document parsed into Markdown and metadata.
		class Document
			# Raised when context front matter cannot be safely interpreted.
			class Invalid < ArgumentError
			end
			
			# Read and parse a document from its source path.
			# @parameter path [String] The Markdown source file.
			# @returns [Document] The parsed document.
			def self.load(path)
				parse(File.read(path), path: path)
			end
			
			# Parse Markdown and validate its front matter.
			# @parameter content [String] The Markdown source content.
			# @parameter path [String] The source path used for error messages.
			# @returns [Document] The parsed document.
			def self.parse(content, path:)
				parts = Markly.parse(content, flags: Markly::FRONT_MATTER).to_a
				front_matter = parts.first if parts.first&.type == :front_matter
				
				metadata = if front_matter
					YAML.safe_load(
						front_matter.string_content,
						permitted_classes: [Date, Time],
						aliases: false,
						fallback: {},
					)
				else
					{}
				end
				
				raise Invalid, "Context frontmatter must be a mapping: #{path}" unless metadata.is_a?(Hash)
				
				new(content, front_matter, metadata)
			rescue Psych::Exception => error
				raise Invalid, "Invalid YAML frontmatter in #{path}: #{error.message}"
			end
			
			# Initialize a document from parsed Markdown and metadata.
			# @parameter content [String] The original Markdown source content.
			# @parameter front_matter [Markly::Node | Nil] The leading front matter node.
			# @parameter metadata [Hash] The decoded front matter.
			def initialize(content, front_matter, metadata)
				@content = content
				@front_matter = front_matter
				@metadata = metadata
			end
			
			# @attribute [Hash] Decoded context metadata.
			attr_reader :metadata
			
			# @returns [String] The original Markdown body after the front matter node.
			def body
				return @content unless @front_matter
				
				@content.lines.drop(@front_matter.source_position[:end_line]).join
			end
		end
	end
end
