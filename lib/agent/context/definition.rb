# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fileutils"

module Agent
	module Context
		# Represents one ordinary file provided in a package's context directory.
		class Definition
			# Initialize a context definition from its source path and parsed document.
			# @parameter path [String] The source file path.
			# @parameter document [Document | Nil] The parsed Markdown document, when applicable.
			def initialize(path:, document: nil)
				@path = path
				@document = document
			end
			
			attr_reader :path
			
			# Whether this definition installs as an Agent Skill.
			# @returns [bool] `false` for ordinary context definitions.
			def skill?
				false
			end
			
			# Read the definition's Markdown content or opaque file contents.
			# @returns [String] The source content.
			def content
				@document ? @document.content : File.read(@path)
			end
			
			# Return the relative name displayed by the context list.
			# @parameter context_path [String] The provider's context directory.
			# @returns [String] The path relative to the provider context directory.
			def display_name(context_path)
				@path.delete_prefix("#{context_path}/")
			end
			
			# Write the definition to its installation destination.
			# @parameter destination [String] The target file path.
			def write_to(destination)
				FileUtils.mkdir_p(File.dirname(destination))
				if @document
					@document.write(destination)
				else
					FileUtils.copy_file(@path, destination, true)
				end
			end
		end
	end
end
