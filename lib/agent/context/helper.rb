# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.

require "rubygems"
require "fileutils"
require "pathname"

module Agent
	module Context
		class Helper
			def initialize(specifications: ::Gem::Specification)
				@context_path = ".context"
				@specifications = specifications
			end
				
			# Find all gems that have a context directory
			def find_gems_with_context
				gems_with_context = []
					
				@specifications.each do |spec|
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
				
			# Find a specific gem with context
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
				
			# List context files for a gem
			def list_context_files(gem_name)
				gem_info = find_gem_with_context(gem_name)
				return nil unless gem_info
					
				Dir.glob(File.join(gem_info[:path], "**/*")).select { |f| File.file?(f) }
			end
				
			# Show content of a specific context file
			def show_context_file(gem_name, file_name)
				gem_info = find_gem_with_context(gem_name)
				return nil unless gem_info
					
				# Try to find the file with or without extension
				possible_paths = [
						File.join(gem_info[:path], file_name),
						File.join(gem_info[:path], "#{file_name}.mdc"),
						File.join(gem_info[:path], "#{file_name}.md")
					]
					
				file_path = possible_paths.find { |path| File.exist?(path) }
				return nil unless file_path
					
				File.read(file_path)
			end
				
			# Install context from a specific gem
			def install_gem_context(gem_name)
				gem_info = find_gem_with_context(gem_name)
				return false unless gem_info
					
				target_path = File.join(@context_path, gem_name)
				FileUtils.mkdir_p(target_path)
					
				# Copy all files from the gem's context directory
				FileUtils.cp_r(File.join(gem_info[:path], "."), target_path)
					
				true
			end
				
			# Install context from all gems
			def install_all_context
				gems = find_gems_with_context
				installed = []
					
				gems.each do |gem_info|
					if install_gem_context(gem_info[:name])
						installed << gem_info[:name]
					end
				end
					
				installed
			end
		end
	end
end 
