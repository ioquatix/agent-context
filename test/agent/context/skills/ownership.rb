# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "agent/context/skills/ownership"
require "fileutils"
require "tmpdir"

describe Agent::Context::Skills::Ownership do
	let(:directory) {Dir.mktmpdir}
	let(:skill_path) {File.join(directory, "provider-workflow")}
	
	def around
		FileUtils.mkdir_p(skill_path)
		yield
	ensure
		FileUtils.rm_rf(directory)
	end
	
	def write_owner(directory, package, version)
		metadata = {"metadata" => {"type" => "skill", "ecosystem" => "gem", "package" => package, "version" => version}}
		File.write(File.join(directory, "SKILL.md"), "#{metadata.to_yaml}---\n")
	end
	
	it "reads ownership from the shared installed skill fixture" do
		fixture = File.expand_path("../../../fixtures/SKILL.md", __dir__)
		FileUtils.copy_file(fixture, File.join(skill_path, "SKILL.md"))
		expected = {"ecosystem" => "cargo", "package" => "provider", "version" => "1.0.0"}
		expect(subject.load(skill_path)).to be == expected
		
	end
	
	it "scans owned directories alongside project skills and other files" do
		write_owner(skill_path, "provider", "1.0.0")
		FileUtils.mkdir_p(File.join(directory, "project-workflow"))
		File.write(File.join(directory, "readme.md"), "Project skills.")
		File.symlink(skill_path, File.join(directory, "linked-workflow"))
		expect(subject.scan(directory)).to be == {"provider-workflow" => subject.load(skill_path)}
		expect(subject.scan(File.join(directory, "missing"))).to be == {}
	end
	
	it "validates ownership before treating an installation as managed" do
		[
			"---\nmetadata: [invalid\n---\n",
			"---\nmetadata:\n  type: skill\n  ecosystem: gem\n---\n",
			"---\nmetadata:\n  type: skill\n  ecosystem: gem\n  package: ' '\n  version: '1.0'\n---\n",
		].each do |content|
			File.write(File.join(skill_path, "SKILL.md"), content)
			expect do
				subject.scan(directory)
			end.to raise_exception(subject::Invalid)
		end
	end
	
	it "reports inaccessible ownership files and installation roots" do
		write_owner(skill_path, "provider", "1.0.0")
		File.chmod(0o400, skill_path)
		expect{subject.load(skill_path)}.to raise_exception(Errno::EACCES)
		expect{subject.scan(File.join(skill_path, "skills"))}.to raise_exception(Errno::EACCES)
	ensure
		File.chmod(0o700, skill_path)
	end
	
	it "requires regular ownership files and skill directories" do
		File.symlink("missing.json", File.join(skill_path, "SKILL.md"))
		expect do
			subject.load(skill_path)
		end.to raise_exception(subject::Invalid)
		File.write(File.join(directory, "blocker"), "Not a directory.")
		expect do
			subject.scan(File.join(directory, "blocker"))
		end.to raise_exception(subject::Invalid)
	end
	
	it "validates the installed directory name" do
		["Bad_Name", "a" * 65].each do |name|
			path = File.join(directory, name)
			FileUtils.mkdir_p(path)
			write_owner(path, "provider", "1.0.0")
			expect do
				subject.scan(directory)
			end.to raise_exception(subject::Invalid)
			FileUtils.rm_rf(path)
		end
	end
	it "keeps project skill metadata separate from installation provenance" do
		["version: '1.0'", "type: skill, version: '1.0'", "ecosystem: gem, package: provider, version: '1.0'"].each do |metadata|
			File.write(File.join(skill_path, "SKILL.md"), "---\nmetadata: {#{metadata}}\n---\nProject instructions.\n")
			expect(subject.scan(directory)).to be == {}
		end
	end
	
end
