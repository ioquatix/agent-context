# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

module Agent
	module Context
		# Base class for errors raised while loading or installing context.
		class Error < StandardError
		end
		
		# Raised when provider content or installation metadata is invalid.
		class InvalidError < Error
		end
		
		# Raised when providers or installation destinations conflict.
		class ConflictError < Error
		end
	end
end
