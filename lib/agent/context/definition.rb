# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fileutils"

module Agent
	module Context
		# Represents one ordinary file provided in a package's context directory.
		class Definition
			def initialize(path:, document: nil)
				@path = path
				@document = document
			end
			
			attr_reader :path
			
			def skill?
				false
			end
			
			def content
				@document ? @document.content : File.read(@path)
			end
			
			def display_name(context_path)
				@path.delete_prefix("#{context_path}/")
			end
			
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
