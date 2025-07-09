# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2024, by Samuel Williams.

require_relative 'version'
require 'fileutils'
require 'markly'

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
			
			# Insert or update the ## Context section in agent.md in the project root
			def update_agent_md(agent_md_path = 'agent.md')
				index_content = generate_context_section

				if File.exist?(agent_md_path)
					doc = Markly.parse(File.read(agent_md_path))
					# Find the # Agent heading
					header_index = doc.children.find_index do |node|
						node.type == :heading && node.string_content.strip =~ /^Agent$/i && node.header_level == 1
					end
					
					if header_index
						# Find or replace ## Context section under # Agent
						context_index = doc.children[header_index+1..].find_index do |node|
							node.type == :heading && node.string_content.strip =~ /^Context$/i && node.header_level == 2
						end
						if context_index
							# Replace the section
							context_index += header_index + 1
							# Remove the old context section (heading + following nodes until next heading of same or higher level)
							end_index = context_index + 1
							while end_index < doc.children.size && !(doc.children[end_index].type == :heading && doc.children[end_index].header_level <= 2)
								end_index += 1
							end
							doc.children.slice!(context_index...end_index)
							doc.children.insert(context_index, *Markly.parse(index_content).children)
						else
							# Insert new ## Context section after # Agent
							doc.children.insert(header_index+1, *Markly.parse(index_content).children)
						end
					else
						# No # Agent header, prepend one
						doc.children.unshift(*Markly.parse("# Agent\n\n").children)
						doc.children.insert(1, *Markly.parse(index_content).children)
					end
					File.write(agent_md_path, doc.to_html(:UNSAFE))
				else
					# Create new agent.md with # Agent and ## Context
					content = "# Agent\n\n" + index_content
					File.write(agent_md_path, Markly.parse(content).to_html(:UNSAFE))
				end
			end

			# Write or update the root-level agent.md file, adding/replacing the ## Context section under # Agent
			def write_to_root_agent_md(path = 'agent.md')
				index_content = generate_context_section

				if File.exist?(path)
					markdown = File.read(path)
					ast = Markly.parse(markdown)

					# Find the # Agent heading
					agent_section = nil
					ast.walk do |node|
						if node.type == :heading && node.string_content.strip =~ /^Agent$/i && node.header_level == 1
							agent_section = node
							break
						end
					end

					if agent_section
						# Find or replace ## Context under # Agent
						context_found = false
						insert_index = nil
						children = ast.children
						children.each_with_index do |child, idx|
							if child.type == :heading && child.header_level == 2 && child.string_content.strip =~ /^Context$/i
								context_found = true
								# Remove all nodes until the next heading of same or higher level
								remove_idx = idx + 1
								while remove_idx < children.size && !(children[remove_idx].type == :heading && children[remove_idx].header_level <= 2)
									children.delete_at(remove_idx)
								end
								# Replace the context heading node with new content
								children[idx] = Markly.parse("## Context\n\n" + index_content).first_child
								break
							end
							# Remember where to insert if not found
							if child == agent_section
								insert_index = idx + 1
							end
						end
						unless context_found
							# Insert after # Agent heading
							children.insert(insert_index, Markly.parse("## Context\n\n" + index_content).first_child)
						end
						# Write back
						File.write(path, ast.to_html.gsub(/<h1>(.*?)<\/h1>/, '# \1').gsub(/<h2>(.*?)<\/h2>/, '## \1').gsub(/<p>/, '').gsub(/<\/p>/, '\n').gsub(/<ul>|<\/ul>/, '').gsub(/<li>/, '- ').gsub(/<\/li>/, '\n'))
					else
						# No # Agent heading, prepend one
						new_content = "# Agent\n\n## Context\n\n" + index_content + "\n\n" + markdown
						File.write(path, new_content)
					end
				else
					# File does not exist, create it
					File.write(path, "# Agent\n\n## Context\n\n" + index_content + "\n")
				end
			end

			# Generate just the context section (without top-level header)
			def generate_context_section
				sections = []
				sections << "This file provides context from installed Ruby gems that offer AI agent documentation."
				sections << "Generated on #{Time.now.strftime('%Y-%m-%d %H:%M:%S')} by agent-context #{VERSION}."
				sections << ""
				gem_contexts = collect_gem_contexts
				if gem_contexts.empty?
					sections << "No context files found. Run `bake agent:context:install` to install context from gems."
					sections << ""
				else
					sections << "### Available Context Files"
					sections << ""
					sections << "The following gems provide context documentation for AI agents:"
					sections << ""
					gem_contexts.each do |gem_name, files|
						sections << "#### #{gem_name}"
						sections << ""
						files.each do |file_path|
							if File.exist?(file_path)
								title, description = extract_content(file_path)
								relative_path = file_path.sub("#{@context_path}/", '')
								sections << "- **[#{title}](#{relative_path})**"
								sections << "  #{description}" if description && !description.empty?
								sections << ""
							end
						end
					end
					sections << "### Usage"
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
