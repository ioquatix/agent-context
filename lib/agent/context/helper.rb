# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "rubygems"
require "fileutils"
require "pathname"

module Agent
	module Context
		# Helper class for managing context files from Ruby gems.
		# 
		# This class provides methods to find, list, show, and install context files
		# from gems that provide them in a `context/` directory.
		class Helper
			# Initialize a new Helper instance.
			#
			# @parameter root [String] The root directory to work from (default: current directory).
			# @parameter specifications [Gem::Specification] The gem specifications to search (default: all installed gems).
			def initialize(root: Dir.pwd, specifications: ::Gem::Specification)
				@root = root
				@context_path = ".context"
				@specifications = specifications
			end
				
			# Find all gems that have a context directory
			def find_gems_with_context(skip_local: true)
				gems_with_context = []
					
				@specifications.each do |spec|
					# Skip gems loaded from current working directory if requested:
					next if skip_local && spec.full_gem_path == @root
					
					context_path = File.join(spec.full_gem_path, "context")
					if Dir.exist?(context_path)
						gems_with_context << {
								name: spec.name,
								version: spec.version.to_s,
								path: context_path
							}
					end
				end
					
				gems_with_context
			end
				
			# Find a specific gem with context.
			def find_gem_with_context(gem_name)
				spec = @specifications.find { |s| s.name == gem_name }
				return nil unless spec
					
				context_path = File.join(spec.full_gem_path, "context")
					
				if Dir.exist?(context_path)
					{
							name: spec.name,
							version: spec.version.to_s,
							path: context_path
						}
				else
					nil
				end
			end
				
			# List context files for a gem.
			def list_context_files(gem_name)
				gem = find_gem_with_context(gem_name)
				return nil unless gem
					
				Dir.glob(File.join(gem[:path], "**/*")).select { |f| File.file?(f) }
			end
				
			# Show content of a specific context file.
			def show_context_file(gem_name, file_name)
				gem = find_gem_with_context(gem_name)
				return nil unless gem
					
				# Try to find the file with or without extension:
				possible_paths = [
						File.join(gem[:path], file_name),
						File.join(gem[:path], "#{file_name}.md"),
						File.join(gem[:path], "#{file_name}.md")
					]
					
				file_path = possible_paths.find { |path| File.exist?(path) }
				return nil unless file_path
					
				File.read(file_path)
			end
				
			# Install context from a specific gem.
			def install_gem_context(gem_name)
				gem = find_gem_with_context(gem_name)
				return false unless gem
					
				target_path = File.join(@context_path, gem_name)
				
				# Remove old package directory if it exists to ensure clean install
				FileUtils.rm_rf(target_path) if Dir.exist?(target_path)
				
				FileUtils.mkdir_p(target_path)
					
				# Copy all files from the gem's context directory:
				FileUtils.cp_r(File.join(gem[:path], "."), target_path)
					
				true
			end
				
			# Install context from all gems.
			def install_all_context(skip_local: true)
				gems = find_gems_with_context(skip_local: skip_local)
				installed = []
					
				gems.each do |gem|
					if install_gem_context(gem[:name])
						installed << gem[:name]
					end
				end
					
				installed
			end
		end
	end
end
