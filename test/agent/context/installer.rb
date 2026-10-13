# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Shopify Inc.
# Copyright, 2025, by Samuel Williams.

require "agent/context/installer"
require "sus/fixtures/console/null_logger"
require "tmpdir"
require "fileutils"

describe Agent::Context::Installer do
	include Sus::Fixtures::Console::NullLogger
	
	with "fake gem with context" do
		let(:gem_root) {Dir.mktmpdir}
		let(:context_path) {File.join(gem_root, "context")}
		
		def around
			# Create a fake gem with context
			FileUtils.mkdir_p(context_path)
			File.write(File.join(context_path, "getting-started.md"), "# Getting Started\n\nThis is a test.")
			File.write(File.join(context_path, "configuration.md"), "# Configuration\n\nConfigure your gem.")
			
			# Create a real Gem::Specification for our fake gem
			fake_spec = ::Gem::Specification.new do |spec|
				spec.name = "fake-gem"
				spec.version = "1.0.0"
				spec.summary = "A fake gem for testing"
				spec.files = ["context/getting-started.md", "context/configuration.md"]
			end
			
			# Set the full_gem_path directly
			fake_spec.instance_variable_set(:@full_gem_path, gem_root)
			
			@specifications = [fake_spec]
			yield
		end
		
		it "can find gems with context" do
			helper = subject.new(specifications: @specifications)
			gems = helper.find_gems_with_context
			
			expect(gems.length).to be == 1
			expect(gems.first[:name]).to be == "fake-gem"
			expect(gems.first[:version]).to be == "1.0.0"
			expect(gems.first[:path]).to be == context_path
		end
		
		it "can find a specific gem with context" do
			helper = subject.new(specifications: @specifications)
			gem_info = helper.find_gem_with_context("fake-gem")
			
			expect(gem_info).to be_truthy
			expect(gem_info[:name]).to be == "fake-gem"
			expect(gem_info[:path]).to be == context_path
		end
		
		it "returns nil for gems without context" do
			helper = subject.new(specifications: @specifications)
			gem_info = helper.find_gem_with_context("non-existent-gem")
			expect(gem_info).to be_nil
		end
		
		it "can list context definitions for a gem" do
			helper = subject.new(specifications: @specifications)
			definitions = helper.list_context_definitions("fake-gem")
			
			expect(definitions.map{|definition| File.basename(definition.path)}).to be == ["configuration.md", "getting-started.md"]
		end
		
		it "can show content of a specific context file" do
			helper = subject.new(specifications: @specifications)
			content = helper.show_context_file("fake-gem", "getting-started")
			expect(content).to be == "# Getting Started\n\nThis is a test."
		end
		
		it "can show content with .md extension" do
			helper = subject.new(specifications: @specifications)
			content = helper.show_context_file("fake-gem", "getting-started.md")
			expect(content).to be == "# Getting Started\n\nThis is a test."
		end
		
		it "returns nil for non-existent files" do
			helper = subject.new(specifications: @specifications)
			content = helper.show_context_file("fake-gem", "non-existent")
			expect(content).to be_nil
		end
		
		with "installation" do
			let(:target_path) {Dir.mktmpdir}
			
			def around
				super do
					Dir.mktmpdir do |install_path|
						@target_path = install_path
						yield
					end
				end
			end
			
			it "can install context from a specific gem" do
				helper = subject.new(root: @target_path, specifications: @specifications)
				
				result = helper.install(gem: "fake-gem")
				expect(result[:context]).to be(:include?, "fake-gem")
				
				target_context_path = File.join(@target_path, ".agents", "context", "fake-gem")
				expect(helper.context_path).to be == File.join(@target_path, ".agents", "context")
				
				# Check that files were copied
				expect(File).to be(:exist?, File.join(target_context_path, "getting-started.md"))
				expect(File).to be(:exist?, File.join(target_context_path, "configuration.md"))
				
				# Check content
				content = File.read(File.join(target_context_path, "getting-started.md"))
				expect(content).to be == "# Getting Started\n\nThis is a test."
			end
			
			it "reports a missing gem" do
				helper = subject.new(specifications: @specifications)
				expect{helper.install(gem: "non-existent-gem")}.to raise_exception(Agent::Context::Error)
			end
			
			it "installs dotfiles and files inside hidden context directories" do
				File.write(File.join(context_path, ".env.example"), "SETTING=value\n")
				FileUtils.mkdir_p(File.join(context_path, ".config"))
				File.write(File.join(context_path, ".config/settings.yaml"), "setting: value\n")
				helper = subject.new(root: @target_path, specifications: @specifications)
				helper.install
				
				target = File.join(helper.context_path, "fake-gem")
				expect(File.read(File.join(target, ".env.example"))).to be == "SETTING=value\n"
				expect(File.read(File.join(target, ".config/settings.yaml"))).to be == "setting: value\n"
			end
			
			it "can install context from all gems" do
				helper = subject.new(root: @target_path, specifications: @specifications)
				
				installed = helper.install
				expect(installed[:context]).to be(:include?, "fake-gem")
				
				# Check that files were copied
				target_context_path = File.join(@target_path, ".agents", "context", "fake-gem")
				expect(File).to be(:exist?, File.join(target_context_path, "getting-started.md"))
				expect(File).to be(:exist?, File.join(target_context_path, "configuration.md"))
			end
			
			it "copies unfamiliar context types alongside skills" do
				guide = "---\nmetadata:\n  type: guide\n---\n\n# Guide\n"
				File.write(File.join(context_path, "guide.md"), guide)
				File.write(File.join(context_path, "workflow.md"), "---\nmetadata:\n  type: skill\ndescription: Run the workflow.\n---\n\n# Workflow\n")
				helper = subject.new(root: @target_path, specifications: @specifications)
				
				expect(helper.install).to be == {context: ["fake-gem"], skills: ["fake-gem-workflow"]}
				expect(File.read(File.join(helper.context_path, "fake-gem/guide.md"))).to be == guide
				expect(File.read(File.join(@target_path, ".agents/skills/fake-gem-workflow/SKILL.md"))).to be(:include?, "# Workflow")
			end
		end
	end
	
	with "gem without context" do
		let(:gem_root) {Dir.mktmpdir}
		
		def around
			# Create a real Gem::Specification for a gem without context
			no_context_spec = ::Gem::Specification.new do |spec|
				spec.name = "no-context-gem"
				spec.version = "1.0.0"
				spec.summary = "A fake gem without context"
				spec.files = ["lib/no-context-gem.rb"]
			end
			
			# Set the full_gem_path directly
			no_context_spec.instance_variable_set(:@full_gem_path, gem_root)
			
			@specifications = [no_context_spec]
			yield
		end
		
		it "does not find gems without context" do
			helper = subject.new(specifications: @specifications)
			gems = helper.find_gems_with_context
			expect(gems.length).to be == 0
		end
		
		it "returns nil for gems without context" do
			helper = subject.new(specifications: @specifications)
			gem_info = helper.find_gem_with_context("no-context-gem")
			expect(gem_info).to be_nil
		end
	end
end 
