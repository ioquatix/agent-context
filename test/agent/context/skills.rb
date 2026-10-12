# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "agent/context"
require "tmpdir"

describe Agent::Context::Installer do
	let(:directory) {Dir.mktmpdir}
	let(:provider) {File.join(directory, "provider")}
	let(:consumer) {File.join(directory, "consumer")}
	let(:specification) do
		specification = Gem::Specification.new do |spec|
			spec.name = "provider"
			spec.version = "1.0.0"
			spec.summary = "Provider guidance."
		end
		specification.instance_variable_set(:@full_gem_path, provider)
		specification
	end
	let(:installer) {subject.new(root: consumer, specifications: [specification])}
	
	def around
		FileUtils.mkdir_p([File.join(provider, "context/workflow/references"), consumer])
		File.write(File.join(provider, "context/guide.md"), "# Guide\n\nUse the provider.")
		File.write(File.join(provider, "context/workflow.md"), "---\nmetadata:\n  type: skill\ndescription: Run the workflow.\nlicense: MIT\n---\n\n# Workflow\n")
		File.write(File.join(provider, "context/workflow/references/checklist.md"), "# Checklist\n")
		yield
	ensure
		FileUtils.rm_rf(directory)
	end
	
	it "enumerates gem specifications during discovery" do
		enumerations = 0
		specifications = Enumerator.new do |yielder|
			enumerations += 1
			yielder << specification
		end
		installer = subject.new(root: consumer, specifications: specifications)
		skills = Agent::Context::Skills::Installer.new(root: consumer, specifications: specifications)
		expect(enumerations).to be == 0
		expect(installer.find_gems_with_context.map{|gem| gem[:name]}).to be == ["provider"]
		expect(skills.find_gems_with_skills.map{|gem| gem[:name]}).to be == ["provider"]
		installer.install
		expect(File.read(File.join(consumer, ".agents/context/provider/guide.md"))).to be == File.read(File.join(provider, "context/guide.md"))
	end
	
	it "installs context and skills without duplicating skill documents or assets" do
		agents = File.join(consumer, "agents.md")
		File.write(agents, "Repository-owned instructions")
		result = installer.install
		expect(result).to be == {context: ["provider"], skills: ["provider-workflow"]}
		expect(File.read(agents)).to be == "Repository-owned instructions"
		expect(File).to be(:exist?, File.join(consumer, ".agents/context/provider/guide.md"))
		expect(File).not.to be(:exist?, File.join(consumer, ".agents/context/provider/workflow.md"))
		skill_root = File.join(consumer, ".agents/skills/provider-workflow")
		expect(File.read(File.join(skill_root, "SKILL.md"))).to be(:include?, "license: MIT")
		expect(File).to be(:exist?, File.join(skill_root, "references/checklist.md"))
		expect(File).not.to be(:exist?, File.join(consumer, ".agents/context/index.md"))
	end
	
	it "copies ordinary document metadata without interpreting descriptions" do
		guide = "---\ndescription: {text: Provider metadata.}\n---\n\n# Guide\n"
		File.write(File.join(provider, "context/guide.md"), guide)
		
		expect(installer.show_context_file("provider", "guide")).to be == guide
		installer.install
		expect(File.read(File.join(consumer, ".agents/context/provider/guide.md"))).to be == guide
	end
	
	it "updates Git exclusions when a provider only has ordinary context" do
		system("git", "init", "--quiet", consumer, exception: true)
		File.delete(File.join(provider, "context/workflow.md"))
		FileUtils.rm_rf(File.join(provider, "context/workflow"))
		
		expect(installer.install(gem: "provider")).to be == {context: ["provider"], skills: []}
		path = ".agents/context/provider/guide.md"
		expect(File.read(File.join(consumer, path))).to be == File.read(File.join(provider, "context/guide.md"))
		_, status = Open3.capture2e("git", "check-ignore", "--quiet", path, chdir: consumer)
		expect(status.success?).to be == true
		expect(File).not.to be(:exist?, File.join(consumer, ".agents/context/index.md"))
	end
	
	it "excludes skill instructions and resources from listing and showing context" do
		expect(installer.list_context_files("provider").map{|path| File.basename(path)}).to be == ["guide.md"]
		expect(installer.show_context_file("provider", "workflow")).to be_nil
		expect(installer.show_context_file("provider", "workflow/references/checklist.md")).to be_nil
		expect do
			installer.show_context_file("provider", "../secret")
		end.to raise_exception(ArgumentError)
	end
	
	it "validates front matter when classifying context documents" do
		File.write(File.join(provider, "context/guide.md"), "---\ndescription: [broken\n---\n\n# Guide")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::Skills::Installer::InvalidSkill)
		expect(File).not.to be(:exist?, File.join(consumer, ".agents/skills/provider-workflow"))
	end
	
	it "installs native front matter and preserves dates and skill body formatting" do
		guide = "--- yaml\ndate: 2026-10-09\nlayout: guide\n---\n\n# Guide\n\nUse the provider.\n"
		File.write(File.join(provider, "context/guide.md"), guide)
		body = "# Workflow\r\n\r\nUse  [reference][guide].\r\n\r\n~~~yaml\r\n---\r\nexample: unchanged\r\n---\r\n~~~\r\n\r\n[guide]: https://example.test\r\n"
		File.binwrite(File.join(provider, "context/workflow.md"), "--- yaml\r\nmetadata:\r\n  type: skill\r\nname: provider-workflow\r\ndescription: Run the workflow.\r\ndate: 2026-10-09\r\nupdated: 2026-10-09T12:30:00Z\r\n---\r\n\r\n#{body}")
		expect(installer.install).to be == {context: ["provider"], skills: ["provider-workflow"]}
		expect(File.read(File.join(consumer, ".agents/context/provider/guide.md"))).to be == guide
		instructions = File.binread(File.join(consumer, ".agents/skills/provider-workflow/SKILL.md"))
		expect(instructions).to be(:end_with?, body)
		metadata = Agent::Context::Document.load(File.join(consumer, ".agents/skills/provider-workflow/SKILL.md")).frontmatter
		expect(metadata["name"]).to be == "provider-workflow"
		expect(metadata["metadata"]["type"]).to be == "skill"
		expect(metadata["date"]).to be == Date.new(2026, 10, 9)
		expect(metadata["updated"]).to be == Time.utc(2026, 10, 9, 12, 30)
	end
	
	it "handles a provider containing only skills" do
		File.delete(File.join(provider, "context/guide.md"))
		installer.install(gem: "provider")
		expect(File).not.to be(:exist?, File.join(consumer, ".agents/context/provider"))
		expect(File).to be(:exist?, File.join(consumer, ".agents/skills/provider-workflow/SKILL.md"))
	end
	
	it "propagates context write failures and refreshes successfully on retry" do
		installer.install
		destination = File.join(consumer, ".agents/context/provider/guide.md")
		File.write(File.join(provider, "context/guide.md"), "# Updated\n")
		mock(File).before(:write) do |path, *|
			raise Errno::EACCES, "Injected context failure" if path == destination
		end
		expect{installer.install_gem_context("provider")}.to raise_exception(Errno::EACCES)
		mock(File).clear
		installer.install_gem_context("provider")
		expect(File.read(destination)).to be == "# Updated\n"
	end
end
