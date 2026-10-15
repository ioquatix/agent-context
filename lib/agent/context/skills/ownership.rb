# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.
# Copyright, 2026, by Samuel Williams.

require_relative "../document"
require_relative "../errors"

module Agent
	module Context
		module Skills
			# Represents installation ownership recorded in each skill directory.
			class Ownership
				FILE_NAME = "SKILL.md"
				NAME_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
				
				# Read a skill's installation ownership.
				# @parameter directory [String] The installed skill directory.
				# @returns [Hash | Nil] Ownership when the skill has an installation record.
				def self.load(directory)
					path = File.join(directory, FILE_NAME)
					
					begin
						stat = File.lstat(path)
					rescue Errno::ENOENT
						return
					end
					
					raise InvalidError, "Skill ownership must be a regular file: #{path}" unless stat.file?
					
					metadata = Document.load(path).metadata
					fields = ["ecosystem", "package", "version"]
					return unless metadata["type"] == "skill" && metadata.key?("ecosystem")
					
					unless fields.all?{|field| metadata[field].is_a?(String) && !metadata[field].strip.empty?}
						raise InvalidError, "Invalid skill ownership: #{path}"
					end
					
					metadata.slice(*fields)
				end
				
				# Collect ownership from installed skill directories.
				# @parameter directory [String] The installed skills root.
				# @returns [Hash(String, Hash)] Skill names and their installation records.
				def self.scan(directory)
					begin
						stat = File.lstat(directory)
					rescue Errno::ENOENT
						return {}
					end
					
					raise InvalidError, "Skill installation path must be a regular directory: #{directory}" unless stat.directory?
					
					Dir.children(directory).sort.each_with_object({}) do |name, owners|
						path = File.join(directory, name)
						next unless File.lstat(path).directory?
						next unless owner = load(path)
						
						unless name.match?(NAME_PATTERN) && name.length <= 64
							raise InvalidError, "Invalid installed skill name: #{name.inspect}"
						end
						
						owners[name] = owner
					end
				end
			end
		end
	end
end
