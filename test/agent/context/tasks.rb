# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "bake"
require "tmpdir"

describe "Agent Context tasks" do
	it "exposes the context task family" do
		Dir.mktmpdir do |root|
			context = Bake::Context.load(root)
			%w[agent:context:list agent:context:show agent:context:install].each do |name|
				expect(context.lookup(name)).to be_truthy
			end
		end
	end
	
	it "lists, shows, and installs context and skills together" do
		Dir.mktmpdir do |root|
			provider = File.join(root, "provider")
			FileUtils.mkdir_p(File.join(provider, "context"))
			File.write(File.join(provider, "context/guide.md"), "# Provider Guide\n\nUse the package.\n")
			File.write(File.join(provider, "context/workflow.md"), "---\nmetadata:\n  type: skill\ndescription: Run the workflow.\n---\n\n# Workflow\n")
			specification = Gem::Specification.new do |spec|
				spec.name = "provider"
				spec.version = "1.0.0"
				spec.summary = "Provider guidance."
			end
			specification.instance_variable_set(:@full_gem_path, provider)
			mock(Gem::Specification).replace(:each){|&block| [specification].each(&block)}
			output = []
			mock($stdout).replace(:puts){|*messages| output.concat(messages)}
			context = Bake::Context.load(root)
			context.call("agent:context:list")
			context.call("agent:context:list", "--gem", "provider")
			context.call("agent:context:list", "--gem", "missing")
			context.call("agent:context:show", "--gem", "provider", "--file", "guide")
			context.call("agent:context:show", "--gem", "provider", "--file", "workflow")
			context.call("agent:context:show", "--gem", "provider", "--file", "missing")
			context.call("agent:context:install", "--gem", "provider")
			expect(output.join("\n")).to be(:include?, "Provider Guide")
			expect(output.join("\n")).to be(:include?, "workflow (skill)")
			expect(output.join("\n")).to be(:include?, "# Workflow")
			expect(output.join("\n")).to be(:include?, "Installed skills: provider-workflow")
			expect(File).to be(:exist?, File.join(root, ".agents/context/provider/guide.md"))
			expect(File).to be(:exist?, File.join(root, ".agents/skills/provider-workflow/SKILL.md"))
			FileUtils.rm_rf(File.join(provider, "context"))
			context.call("agent:context:list")
			context.call("agent:context:install")
			expect(output).to be(:include?, "No gems with context found")
			expect(File).not.to be(:exist?, File.join(root, ".agents/skills/provider-workflow"))
		end
	end
end
