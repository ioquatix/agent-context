# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "fileutils"
require "pathname"
require_relative "definition"
require_relative "document"
require_relative "skills/definition"
require_relative "errors"

module Agent
	module Context
		# Represents a resolved gem and its loaded context definitions.
		class Package
			# Load and classify a gem's context, keeping skill resources opaque.
			def self.load(specification)
				package = new(specification, [])
				root = package.context_path
				return unless File.exist?(root) || File.symlink?(root)
				
				unless File.lstat(root).directory?
					raise InvalidError, "Context provider must be a regular directory: #{root}"
				end
				
				package.load_directory(root)
				package
			end
			
			# Retain the provider and its loaded definitions.
			def initialize(specification, definitions)
				@specification = specification
				@definitions = definitions
			end
			
			# @attribute [Gem::Specification] The resolved provider.
			attr_reader :specification
			
			# @attribute [Array(Definition)] All loaded context definitions.
			attr_reader :definitions
			
			# @returns [String] The provider gem name.
			def name
				@specification.name
			end
			
			# @returns [String] The provider gem version.
			def version
				@specification.version.to_s
			end
			
			# @returns [String] The provider context directory.
			def context_path
				File.join(@specification.full_gem_path, "context")
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
							raise InvalidError, "Skill documents must be directly inside context/: #{file}" unless directory == context_path
							@definitions << Skills::Definition.from_document(document, @specification)
						else
							@definitions << Definition.new(file.delete_prefix("#{context_path}/"), file, document)
						end
					end
				end
				
				# Companion resources belong to the skill and are copied as opaque files:
				resources = @definitions.grep(Skills::Definition).map(&:resources)
				directories.each do |directory|
					load_directory(directory) unless resources.include?(directory)
				end
				@definitions.sort_by!(&:path)
			end
			
			# Find an authored source path, optionally omitting .md, then an installed skill name.
			def find_definition(file)
				requested = Pathname.new(file)
				if file.empty? || requested.absolute? || requested.each_filename.any?{|part| part == ".." || part == "."}
					raise InvalidError, "Context file must be a relative path inside context/"
				end
				
				candidates = [file]
				candidates << "#{file}.md" if File.extname(file).empty?
				candidates.each do |path|
					definition = @definitions.find{|item| item.path == path}
					return definition if definition
				end
				@definitions.find{|item| item.skill? && item.name == file}
			end
			
			# Refresh ordinary context from the loaded documents and opaque resources.
			def install_files(destination)
				files = @definitions.reject(&:skill?)
				FileUtils.rm_rf(destination)
				return false if files.empty?
				
				files.each do |definition|
					target = File.join(destination, definition.path)
					definition.write_to(target)
				end
				true
			end
		end
	end
end
