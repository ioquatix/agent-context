# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fileutils"

module Agent
	module Context
		# Represents one ordinary file provided in a package's context directory.
		class Definition
			# Initialize a context definition from its paths and parsed document.
			# @parameter path [String] The path relative to the provider's context directory.
			# @parameter source_path [String] The source file path.
			# @parameter document [Document | Nil] The parsed Markdown document, when applicable.
			def initialize(path, source_path, document = nil)
				@path = path
				@source_path = source_path
				@document = document
			end
			
			# @attribute [String] The path relative to the provider's context directory.
			attr_reader :path
			
			# @attribute [String] The source file path.
			attr_reader :source_path
			
			# Whether this definition installs as an Agent Skill.
			# @returns [bool] `false` for ordinary context definitions.
			def skill?
				false
			end
			
			# Read the definition's Markdown content or opaque file contents.
			# @returns [String] The source content.
			def content
				@document ? @document.content : File.read(@source_path)
			end
			
			# Return the relative name displayed by the context list.
			# @returns [String] The path relative to the provider context directory.
			def display_name
				@path
			end
			
			# Write the definition to its installation destination.
			# @parameter destination [String] The target file path.
			def write_to(destination)
				FileUtils.mkdir_p(File.dirname(destination))
				if @document
					@document.write(destination)
				else
					FileUtils.copy_file(@source_path, destination, true)
				end
			end
		end
	end
end
