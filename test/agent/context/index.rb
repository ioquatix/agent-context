# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.

require 'agent/context/index'
require 'tmpdir'
require 'fileutils'

describe Agent::Context::Index do
	with "empty context directory" do
		let(:temp_dir) { Dir.mktmpdir }
		let(:context_path) { File.join(temp_dir, '.context') }
		
		def around
			FileUtils.mkdir_p(context_path)
			yield
		ensure
			FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
		end
		
		it "generates index with no context message" do
			index = Agent::Context::Index.new(context_path)
			content = index.generate
			expect(content).to be(:include?, "# Agent Context")
			expect(content).to be(:include?, "No context files found")
		end
	end
	
	with "context files from gems" do
		let(:temp_dir) { Dir.mktmpdir }
		let(:context_path) { File.join(temp_dir, '.context') }
		
		def around
			FileUtils.mkdir_p(context_path)
			
			# Create a mock gem context
			gem_dir = File.join(context_path, 'example_gem')
			FileUtils.mkdir_p(gem_dir)
			
			# Create a README.md file
			readme_content = <<~MARKDOWN
				# Example Gem
				
				This is an example gem that provides context for AI agents.
				It includes various utilities and helpers.
				
				## Installation
				
				Add this to your Gemfile...
			MARKDOWN
			
			File.write(File.join(gem_dir, 'README.md'), readme_content)
			
			# Create a usage.md file
			usage_content = <<~MARKDOWN
				# Usage Guide
				
				Here's how to use this gem effectively.
				
				## Basic Usage
				
				Start by requiring the gem...
			MARKDOWN
			
			File.write(File.join(gem_dir, 'usage.md'), usage_content)
			
			yield
		ensure
			FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
		end
		
		it "generates index with gem context" do
			index = Agent::Context::Index.new(context_path)
			content = index.generate
			
			expect(content).to be(:include?, "## Available Context Files")
			expect(content).to be(:include?, "### example_gem")
			expect(content).to be(:include?, "- **[Example Gem](example_gem/README.md)**")
			expect(content).to be(:include?, "This is an example gem that provides context")
			expect(content).to be(:include?, "**[Usage Guide]")
			expect(content).to be(:include?, "Here's how to use this gem effectively")
		end
		
		it "writes index to file" do
			index = Agent::Context::Index.new(context_path)
			index.write_to_file()
			
			# Default path should be .context/agent.md
			default_path = File.join(context_path, 'agent.md')
			expect(File.exist?(default_path)).to be == true
			content = File.read(default_path)
			expect(content).to be(:include?, "# Agent Context")
		end
	end
	
	with "title and description extraction" do
		let(:temp_dir) { Dir.mktmpdir }
		let(:context_path) { File.join(temp_dir, '.context') }
		
		def around
			FileUtils.mkdir_p(context_path)
			yield
		ensure
			FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
		end
		
		it "extracts title from markdown header" do
			index = Agent::Context::Index.new(context_path)
			lines = [
				"# My Great Title",
				"",
				"This is the description paragraph.",
				"It continues here.",
				"",
				"## Another section"
			]
			
			title = index.send(:extract_title, lines)
			expect(title).to be == "My Great Title"
		end
		
		it "extracts description from first paragraph" do
			index = Agent::Context::Index.new(context_path)
			lines = [
				"# Title",
				"",
				"This is the first paragraph.",
				"It continues on this line.",
				"",
				"This is the second paragraph."
			]
			
			description = index.send(:extract_description, lines)
			expect(description).to be == "This is the first paragraph. It continues on this line."
		end
		
		it "truncates long descriptions" do
			index = Agent::Context::Index.new(context_path)
			long_line = "This is a very long description that should be truncated because it exceeds the maximum length limit that we have set for descriptions in the index to keep things readable and concise for users who want to understand what each context file contains and decide whether it's relevant to them."
			lines = ["# Title", "", long_line]
			
			description = index.send(:extract_description, lines)
			expect(description).to be(:include?, "...")
			expect(description.length).to be <= 200
		end
	end
end
