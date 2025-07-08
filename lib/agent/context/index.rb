# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative 'version'
require 'fileutils'

module Agent
	module Context
		class Index
			def initialize(context_path = '.context')
				@context_path = context_path
			end
			
			attr :context_path
			
			def generate
				sections = []
				
				# Add header following AGENT.md format
				sections << "# Agent Context"
				sections << ""
				sections << "This file provides context from installed Ruby gems that offer AI agent documentation."
				sections << "Generated on #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} by agent-context #{VERSION}."
				sections << ""
				
				# Collect all markdown files from context directories
				gem_contexts = collect_gem_contexts
				
				if gem_contexts.empty?
					sections << "## Installation"
					sections << ""
					sections << "No context files found. Run `bake agent:context:install` to install context from gems."
					sections << ""
				else
					sections << "## Available Context Files"
					sections << ""
					sections << "The following gems provide context documentation for AI agents:"
					sections << ""
					
					gem_contexts.each do |gem_name, files|
						sections << "### #{gem_name}"
						sections << ""
						
						files.each do |file_path|
							if File.exist?(file_path)
								title, description = extract_content(file_path)
								relative_path = file_path.sub("#{@context_path}/", '')
								
								sections << "- **[#{title}](#{relative_path})**"
								if description && !description.empty?
									sections << "  #{description}"
								end
								sections << ""
							end
						end
					end
					
					sections << "## Usage"
					sections << ""
					sections << "These context files provide information about:"
					sections << "- Gem functionality and APIs"
					sections << "- Usage examples and patterns"
					sections << "- Configuration and setup instructions"
					sections << "- Best practices and conventions"
					sections << ""
					sections << "AI agents can reference these files to understand how to work with the installed gems."
				end
				
				sections.join("\n")
			end
			
			def write_to_file(output_path = nil)
				# Default to .context/agent.md as per AGENT.md specification
				output_path ||= File.join(@context_path, 'agent.md')
				
				content = generate
				
				# Ensure the directory exists
				FileUtils.mkdir_p(File.dirname(output_path)) unless File.dirname(output_path) == '.'
				
				File.write(output_path, content)
				puts "Generated documentation index: #{output_path}"
			end
			
			private
			
			def collect_gem_contexts
				gem_contexts = {}
				
				return gem_contexts unless Dir.exist?(@context_path)
				
				Dir.glob("#{@context_path}/*").each do |gem_dir|
					next unless File.directory?(gem_dir)
					
					gem_name = File.basename(gem_dir)
					markdown_files = Dir.glob("#{gem_dir}/**/*.md").sort
					
					gem_contexts[gem_name] = markdown_files if markdown_files.any?
				end
				
				gem_contexts
			end
			
			def extract_content(file_path)
				content = File.read(file_path)
				lines = content.lines.map(&:strip)
				
				title = extract_title(lines)
				description = extract_description(lines)
				
				[title, description]
			end
			
			def extract_title(lines)
				# Look for the first markdown header
				header_line = lines.find { |line| line.start_with?('#') }
				if header_line
					# Remove markdown header syntax and clean up
					header_line.sub(/^#+\s*/, '').strip
				else
					# If no header found, use the filename or a default
					"Documentation"
				end
			end
			
			def extract_description(lines)
				# Skip empty lines and headers to find the first paragraph
				content_start = false
				description_lines = []
				
				lines.each do |line|
					# Skip headers
					next if line.start_with?('#')
					
					# Skip empty lines until we find content
					if !content_start && line.empty?
						next
					end
					
					# Mark that we've found content
					content_start = true
					
					# If we hit an empty line after finding content, we've reached the end of the first paragraph
					if line.empty?
						break
					end
					
					description_lines << line
				end
				
				# Join the lines and truncate if too long
				description = description_lines.join(' ').strip
				if description.length > 197
					description = description[0..196] + '...'
				end
				
				description
			end
		end
	end
end
