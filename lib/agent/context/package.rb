# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "fileutils"
require_relative "document"
require_relative "skills/definition"

module Agent
	module Context
		# Represents a resolved gem and its loaded context documents and skills.
		class Package
			# Load and classify a gem's context, keeping skill resources opaque.
			def self.load(specification)
				package = new(specification, {}, [])
				root = package.path
				return package unless File.exist?(root) || File.symlink?(root)
				
				unless File.lstat(root).directory?
					raise Skills::Installer::InvalidSkill, "Context provider must be a regular directory: #{root}"
				end
				
				package.load_directory(root)
				package
			rescue Document::Invalid => error
				raise Skills::Installer::InvalidSkill, error.message
			end
			
			# Retain the provider and its classified files.
			def initialize(specification, files, skills)
				@specification = specification
				@files = files
				@skills = skills
			end
			
			# @attribute [Gem::Specification] The resolved provider.
			attr_reader :specification
			
			# @attribute [Hash(String, Document | Nil)] Ordinary files and loaded Markdown.
			attr_reader :files
			
			# @attribute [Array(Skills::Definition)] Prepared skill definitions.
			attr_reader :skills
			
			# @returns [String] The provider gem name.
			def name
				@specification.name
			end
			
			# @returns [String] The provider context directory.
			def path
				File.join(@specification.full_gem_path, "context")
			end
			
			# Describe a provider for command presentation.
			def information
				{
					name: name,
					version: @specification.version.to_s,
					summary: @specification.summary,
					metadata: @specification.metadata,
					path: path,
					skills: @skills,
				}
			end
			
			# Load Markdown before descending into companion directories.
			def load_directory(directory)
				# Classify declarations before traversing their resource directories:
				directories = []
				Dir.children(directory).sort.each do |name|
					file = File.join(directory, name)
					stat = File.lstat(file)
					if stat.directory?
						directories << file
					elsif stat.file?
						document = File.extname(file).downcase == ".md" ? Document.load(file) : nil
						if document&.skill?
							raise Skills::Installer::InvalidSkill, "Skill documents must be directly inside context/: #{file}" unless directory == path
							@skills << Skills::Definition.from_document(document, @specification)
						else
							@files[file] = document
						end
					end
				end
				
				# Companion resources belong to the skill and are copied as opaque files:
				resources = @skills.map(&:path)
				directories.each do |directory|
					load_directory(directory) unless resources.include?(directory)
				end
				@skills.sort_by!(&:name)
			end
			
			# Refresh ordinary context from the loaded documents and opaque resources.
			def install(destination)
				FileUtils.rm_rf(destination)
				return false if @files.empty?
				
				@files.each do |source, document|
					target = File.join(destination, source.delete_prefix("#{path}/"))
					FileUtils.mkdir_p(File.dirname(target))
					if document
						document.write(target)
					else
						FileUtils.copy_file(source, target, true)
					end
				end
				true
			end
		end
	end
end
