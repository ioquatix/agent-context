# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "agent/context/installer"
require "tmpdir"

describe Agent::Context::Exclusion do
	let(:directory) {Dir.mktmpdir}
	
	def around
		yield
	ensure
		FileUtils.rm_rf(directory)
	end
	
	it "scopes Git exclusions to each project in a repository" do
		system("git", "init", "--quiet", directory, exception: true)
		exclusion = Agent::Context::Exclusion
		["", "apps/web [dev]", "apps/worker"].each do |relative|
			root = File.join(directory, relative)
			FileUtils.mkdir_p(root)
			exclusion.prepare(root, ["provider-old"]).apply
		end
		exclusion.prepare(File.join(directory, "apps/web [dev]"), ["provider-new"]).apply
		exclusion.prepare(directory, ["provider-old"]).apply
		
		{
			".agents/skills/provider-old/SKILL.md" => true,
			"apps/worker/.agents/skills/provider-old/SKILL.md" => true,
			"apps/web [dev]/.agents/context/provider/guide.md" => true,
			"apps/web [dev]/.agents/skills/provider-new/SKILL.md" => true,
			"apps/web [dev]/.agents/skills/provider-old/SKILL.md" => false,
			"apps/web [dev]/.agents/skills/project-local/SKILL.md" => false,
			"apps/web d/.agents/skills/provider-new/SKILL.md" => false,
		}.each do |path, ignored|
			_, status = Open3.capture2e("git", "check-ignore", "--quiet", path, chdir: directory)
			expect(status.success?).to be == ignored
		end
	end
	
	it "maintains local exclusions without hiding project-owned instructions or skills" do
		system("git", "init", "--quiet", directory, exception: true)
		exclude = File.join(directory, ".git", "info", "exclude")
		File.write(exclude, "user-rule\n")
		skill = File.join(directory, ".agents", "skills", "cargo-workflow")
		FileUtils.mkdir_p(skill)
		File.write(File.join(skill, "SKILL.md"), "---\nmetadata:\n  type: skill\n  ecosystem: cargo\n  package: provider\n  version: 1.0.0\n---\n")
		Agent::Context::Installer.new(root: directory, specifications: []).install
		first = File.read(exclude)
		Agent::Context::Installer.new(root: directory, specifications: []).install
		expect(File.read(exclude)).to be == first
		expect(first).to be(:include?, "user-rule")
		expect(first).to be(:include?, "/.agents/skills/cargo-workflow/")
		expect(first.lines).not.to be(:include?, "/.agents/\n")
		expect(first.lines).not.to be(:include?, "/.agents/skills/\n")
	end
end
