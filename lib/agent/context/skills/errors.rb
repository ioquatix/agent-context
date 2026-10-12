# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Agent
	module Context
		module Skills
			class Error < StandardError
			end
			
			class Invalid < Error
			end
			
			class Conflict < Error
			end
		end
	end
end
