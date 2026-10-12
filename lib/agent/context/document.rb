# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "markly"
require "yaml"
require "date"

module Agent
	module Context
		# Represents a Markdown source and its parsed front matter.
		class Document
			# Raised when context front matter cannot be interpreted.
			class Invalid < ArgumentError
			end
			
			# Read and parse a Markdown document.
			def self.load(path)
				parse(File.read(path), path: path)
			end
			
			# Parse YAML front matter using Markdown's native syntax tree.
			def self.parse(content, path:)
				# Let Markly identify the front matter and its source boundary:
				first = Markly.parse(content, flags: Markly::FRONT_MATTER).first_child
				node = first if first&.type == :front_matter
				language = node&.fence_info&.split&.first
				
				# Interpret YAML metadata, keeping other formats opaque:
				frontmatter = {}
				if node && [nil, "yaml", "yml"].include?(language)
					frontmatter = YAML.safe_load(node.string_content, permitted_classes: [Date, Time], aliases: false, fallback: {})
					raise Invalid, "Context frontmatter must be a mapping: #{path}" unless frontmatter.is_a?(Hash)
				end
				
				new(path, content, node, frontmatter)
			rescue Psych::Exception => error
				raise Invalid, "Invalid YAML frontmatter in #{path}: #{error.message}"
			end
			
			# Retain the source and its parsed representation.
			def initialize(path, content, node, frontmatter)
				@path = path
				@content = content
				@node = node
				@frontmatter = frontmatter
			end
			
			# @attribute [String] The document source path.
			attr_reader :path
			
			# @attribute [String] The original Markdown source.
			attr_reader :content
			
			# @attribute [Hash] The decoded YAML front matter.
			attr_reader :frontmatter
			
			# The extensible metadata mapping within front matter.
			def metadata
				value = @frontmatter["metadata"]
				value.is_a?(Hash) ? value : {}
			end
			
			# Classify documents from their context metadata.
			def skill?
				type = metadata["type"]
				unless type.nil? || type == "skill"
					raise Invalid, "Unsupported context type in #{@path}: #{type.inspect}"
				end
				
				type == "skill"
			end
			
			# The original body following the parser's front matter boundary.
			def body
				return @content unless @node
				
				@content.lines.drop(@node.source_position[:end_line]).join
			end
			
			# Serialize edited front matter through its AST node, preserving the body.
			def render(frontmatter)
				@node.string_content = YAML.dump(frontmatter).delete_prefix("---\n")
				@node.to_markdown + body
			end
			
			# Write the loaded source to its destination.
			def write(path)
				File.write(path, @content)
			end
		end
	end
end
