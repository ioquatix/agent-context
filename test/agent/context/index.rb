# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Samuel Williams.
# Copyright, 2025, by Shopify Inc.

require "agent/context/index"
require "tmpdir"
require "fileutils"

describe Agent::Context::Index do

	
	with "AGENT.md functionality" do
		let(:temp_dir) { Dir.mktmpdir }
		let(:context_path) { File.join(temp_dir, ".context") }
		let(:agent_md_path) { File.join(temp_dir, "agent.md") }
		
		def around
			FileUtils.mkdir_p(context_path)
			yield
		ensure
			FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
		end
		
		it "creates new AGENT.md when file doesn't exist" do
			index = Agent::Context::Index.new(context_path)
			index.update_agent_md(agent_md_path)
			
			expect(File.exist?(agent_md_path)).to be == true
			content = File.read(agent_md_path)
			expect(content).to be(:include?, "# Agent")
			expect(content).to be(:include?, "## Context")
			expect(content).to be(:include?, "No context files found")
		end
		
		it "updates existing AGENT.md with context section" do
			# Create an existing AGENT.md
			existing_content = <<~MARKDOWN
				# Agent
				
				This is an existing AGENT.md file.
				
				## Build & Commands
				
				Run `bake test` to run tests.
			MARKDOWN
			
			File.write(agent_md_path, existing_content)
			
			index = Agent::Context::Index.new(context_path)
			index.update_agent_md(agent_md_path)
			
			content = File.read(agent_md_path)
			expect(content).to be(:include?, "# Agent")
			expect(content).to be(:include?, "## Context")
			expect(content).to be(:include?, "## Build & Commands")
			expect(content).to be(:include?, "No context files found")
		end
		
		it "replaces existing context section" do
			# Create an existing AGENT.md with context section
			existing_content = <<~MARKDOWN
				# Agent
				
				## Context
				
				Old context content here.
				
				## Build & Commands
				
				Run `bake test` to run tests.
			MARKDOWN
			
			File.write(agent_md_path, existing_content)
			
			index = Agent::Context::Index.new(context_path)
			index.update_agent_md(agent_md_path)
			
			content = File.read(agent_md_path)
			expect(content).to be(:include?, "# Agent")
			expect(content).to be(:include?, "## Context")
			expect(content).to be(:include?, "## Build & Commands")
			expect(content).to be(:include?, "No context files found")
			expect(content).not.to be(:include?, "Old context content here")
		end
		
		it "handles AGENT.md without # Agent heading" do
			# Create an existing file without # Agent heading
			existing_content = <<~MARKDOWN
				# Project Documentation
				
				This is a project without an Agent heading.
				
				## Build & Commands
				
				Run `bake test` to run tests.
			MARKDOWN
			
			File.write(agent_md_path, existing_content)
			
			index = Agent::Context::Index.new(context_path)
			index.update_agent_md(agent_md_path)
			
			content = File.read(agent_md_path)
			expect(content).to be(:include?, "# Agent")
			expect(content).to be(:include?, "## Context")
			expect(content).to be(:include?, "# Project Documentation")
		end
		
		it "generates context section with gem content" do
			# Create a mock gem context
			gem_dir = File.join(context_path, "example_gem")
			FileUtils.mkdir_p(gem_dir)
			
			readme_content = <<~MARKDOWN
				# Example Gem
				
				This is an example gem that provides context for AI agents.
			MARKDOWN
			
			File.write(File.join(gem_dir, "README.md"), readme_content)
			
			index = Agent::Context::Index.new(context_path)
			index.update_agent_md(agent_md_path)
			
			content = File.read(agent_md_path)
			expect(content).to be(:include?, "# Agent")
			expect(content).to be(:include?, "## Context")
			expect(content).to be(:include?, "### example_gem")
			expect(content).to be(:include?, "#### [Example Gem](.context/example_gem/README.md)")
			expect(content).to be(:include?, "This is an example gem that provides context for AI agents")
		end
	end
	
	with "title and description extraction" do
		let(:temp_dir) { Dir.mktmpdir }
		let(:context_path) { File.join(temp_dir, ".context") }
		
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
