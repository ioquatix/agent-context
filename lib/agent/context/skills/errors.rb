# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Agent
	module Context
		module Skills
			# Represents an error during dependency skill processing.
			class Error < StandardError
			end
			
			# Represents invalid skill definitions or ownership metadata.
			class Invalid < Error
			end
			
			# Represents a conflict with an existing skill destination.
			class Conflict < Error
			end
		end
	end
end
