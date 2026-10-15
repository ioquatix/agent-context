# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "agent/context"
require "tmpdir"

describe Agent::Context::Installer do
	let(:consumer_root) {Dir.mktmpdir}
	let(:provider_root) {Dir.mktmpdir}
	let(:specifications) {[build_specification("fake-gem", "1.0.0", provider_root)]}
	let(:installer) {subject.new(root: consumer_root, specifications: specifications)}
	
	def around
		write_skill(provider_root, "ruby-testing", description: "Test Ruby projects with Sus.")
		yield
	ensure
		FileUtils.rm_rf(consumer_root)
		FileUtils.rm_rf(provider_root)
	end
	
	def build_specification(name, version, root)
		specification = Gem::Specification.new do |spec|
			spec.name = name
			spec.version = version
			spec.summary = "A gem providing agent skills."
		end
		specification.instance_variable_set(:@full_gem_path, root)
		specification
	end
	
	def write_skill(root, name, description:, body: "# Instructions\n\nFollow these instructions.\n")
		directory = File.join(root, "context")
		FileUtils.mkdir_p(directory)
		metadata = {"metadata" => {"type" => "skill"}, "description" => description}
		File.write(File.join(directory, "#{name}.md"), "#{metadata.to_yaml}---\n\n#{body}")
	end
	
	def write_owner(directory, package, version, ecosystem: "gem", body: "Instructions")
		metadata = {"metadata" => {"type" => "skill", "ecosystem" => ecosystem, "package" => package, "version" => version}}
		File.write(File.join(directory, "SKILL.md"), "#{metadata.to_yaml}---\n\n#{body}")
	end
	
	def skill_definitions(gem_name)
		Array(installer.find_provider(gem_name)&.definitions).grep(Agent::Context::Skills::Definition)
	end
	
	it "finds gems which provide skills" do
		gems = installer.providers
		
		expect(gems.length).to be == 1
		expect(gems.first.name).to be == "fake-gem"
		expect(gems.first.definitions.grep(Agent::Context::Skills::Definition).map(&:name)).to be == ["fake-gem-ruby-testing"]
	end
	
	it "lists skills provided by a gem" do
		skills = skill_definitions("fake-gem")
		
		expect(skills.length).to be == 1
		expect(skills.first).to have_attributes(
			name: be == "fake-gem-ruby-testing",
			description: be == "Test Ruby projects with Sus."
		)
	end
	
	it "shows a skill instruction file" do
		content = installer.show_context_file("fake-gem", "fake-gem-ruby-testing")
		
		expect(content).to be == File.read(File.join(provider_root, "context/ruby-testing.md"))
		expect(content).to be(:include?, "# Instructions")
	end
	
	it "returns nil for a gem without skills" do
		expect(installer.find_provider("missing-gem")).to be_nil
		expect do
			installer.install(gem: "missing-gem")
		end.to raise_exception(Agent::Context::Error)
	end
	
	it "ignores legacy skill bundles and discovers only context metadata" do
		FileUtils.mkdir_p(File.join(provider_root, "skills", "legacy"))
		File.write(File.join(provider_root, "skills/legacy/SKILL.md"), "---\nname: legacy\ndescription: Legacy instructions.\n---\n")
		
		expect(skill_definitions("fake-gem").map(&:name)).to be == ["fake-gem-ruby-testing"]
		File.delete(File.join(provider_root, "context/ruby-testing.md"))
		expect(installer.providers.first.definitions).to be == []
	end
	
	it "skips a gem loaded from the consuming project by default" do
		write_skill(consumer_root, "local-development", description: "Develop the local gem.")
		local_specification = build_specification("local-gem", "1.0.0", consumer_root)
		local_installer = subject.new(root: consumer_root, specifications: [local_specification])
		
		expect(local_installer.providers).to be == []
		expect(local_installer.providers(skip_local: false).map(&:name)).to be == ["local-gem"]
	end
	
	with "installation" do
		it "installs skills relative to the consuming project root" do
			installed = installer.install(gem: "fake-gem")
			destination = File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing")
			
			expect(installed[:skills]).to be == ["fake-gem-ruby-testing"]
			expect(File).to be(:exist?, File.join(destination, "SKILL.md"))
		end
		
		it "records ownership in the installed front matter" do
			installer.install(gem: "fake-gem")
			path = File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing")
			
			expect(Agent::Context::Skills::Ownership.load(path)).to be == {
				"ecosystem" => "gem",
				"package" => "fake-gem",
				"version" => "1.0.0",
			}
		end
		
		it "updates a skill owned by the same gem" do
			installer.install(gem: "fake-gem")
			write_skill(provider_root, "ruby-testing", description: "Updated description.", body: "# Updated\n")
			installer.install(gem: "fake-gem")
			
			content = File.read(File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing", "SKILL.md"))
			expect(content).to be(:include?, "# Updated")
		end
		
		it "removes skills no longer provided by the same gem" do
			write_skill(provider_root, "documentation", description: "Write documentation.")
			installer.install(gem: "fake-gem")
			File.delete(File.join(provider_root, "context", "documentation.md"))
			installer.install(gem: "fake-gem")
			
			expect(File).not.to be(:exist?, File.join(consumer_root, ".agents", "skills", "fake-gem-documentation"))
		end
		
		it "refuses to overwrite an unmanaged skill" do
			destination = File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing")
			FileUtils.mkdir_p(destination)
			File.write(File.join(destination, "SKILL.md"), "project-owned")
			
			expect do
				installer.install(gem: "fake-gem")
			end.to raise_exception(Agent::Context::ConflictError)
			
			expect(File.read(File.join(destination, "SKILL.md"))).to be == "project-owned"
		end
		
		it "reports a file occupying the skills directory" do
			destination = File.join(consumer_root, ".agents", "skills")
			FileUtils.mkdir_p(File.dirname(destination))
			File.write(destination, "project-owned")
			
			expect do
				installer.install
			end.to raise_exception(Agent::Context::InvalidError)
			
			expect(File.read(destination)).to be == "project-owned"
		end
		
		it "refuses duplicate skill names from different gems before installation" do
			second_root = Dir.mktmpdir
			write_skill(second_root, "ruby-testing", description: "Another implementation.")
			duplicate_specifications = specifications + [build_specification("fake_gem", "1.0.0", second_root)]
			duplicate_installer = subject.new(root: consumer_root, specifications: duplicate_specifications)
			
			expect do
				duplicate_installer.install
			end.to raise_exception(Agent::Context::ConflictError)
			
			expect(File).not.to be(:exist?, File.join(consumer_root, ".agents", "skills", "fake-gem-ruby-testing"))
		ensure
			FileUtils.rm_rf(second_root) if second_root
		end
		
		it "installs uniquely named skills from multiple gems" do
			second_root = Dir.mktmpdir
			write_skill(second_root, "documentation", description: "Write project documentation.")
			all_specifications = specifications + [build_specification("other-gem", "2.0.0", second_root)]
			all_installer = subject.new(root: consumer_root, specifications: all_specifications)
			
			expect(all_installer.install[:skills].sort).to be == ["fake-gem-ruby-testing", "other-gem-documentation"]
			expect(File).to be(:exist?, File.join(consumer_root, ".agents", "skills", "other-gem-documentation", "SKILL.md"))
		ensure
			FileUtils.rm_rf(second_root) if second_root
		end
	end
	
	with "validation" do
		it "preserves an authored name and uses it as the installed directory" do
			file = File.join(provider_root, "context/ruby-testing.md")
			File.write(file, "---\nmetadata:\n  type: skill\nname: provider-authored\ndescription: Test projects.\n---\n\n# Instructions\n")
			expect(installer.show_context_file("fake-gem", "provider-authored")).to be(:include?, "name: provider-authored")
		end
		
		it "lists unmarked documents as ordinary context" do
			File.write(File.join(provider_root, "context/ruby-testing.md"), "# Plain guidance\n")
			expect(skill_definitions("fake-gem")).to be == []
			expect(installer.providers.map(&:name)).to be == ["fake-gem"]
		end
		
		it "installs skills alongside unfamiliar context types" do
			file = File.join(provider_root, "context/guide.md")
			File.write(file, "---\nmetadata:\n  type: unknown\n---\n\n# Instructions\n")
			
			expect(installer.install[:skills]).to be == ["fake-gem-ruby-testing"]
		end
		
		it "requires a nonempty string description" do
			[nil, 123, "   "].each do |description|
				write_skill(provider_root, "ruby-testing", description: description)
				
				expect do
					installer.install
				end.to raise_exception(Agent::Context::InvalidError)
			end
			
			expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills"))
		end
		
		it "requires a directory for companion resources" do
			File.write(File.join(provider_root, "context/ruby-testing"), "Not a directory")
			
			expect do
				installer.install
			end.to raise_exception(Agent::Context::InvalidError)
			
			expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills"))
		end
	end
	
	it "installs context-declared skills with metadata and opaque resources" do
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(File.join(context, "workflow/references"))
		File.write(File.join(context, "workflow.md"), "---\ndescription: Run workflow.\nlicense: MIT\nmetadata:\n  type: skill\n  author: Provider\n---\n\n# Workflow\n")
		File.write(File.join(context, "workflow/references/data.md"), "---\nnot valid: [yaml\n---\n")
		expect(installer.install(gem: "fake-gem")[:skills].sort).to be == ["fake-gem-ruby-testing", "fake-gem-workflow"]
		content = File.read(File.join(consumer_root, ".agents/skills/fake-gem-workflow/SKILL.md"))
		expect(content).to be(:include?, "name: fake-gem-workflow")
		expect(content).to be(:include?, "license: MIT")
		expect(content).to be(:include?, "author: Provider")
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-workflow/references/data.md"))
	end
	
	it "removes a provider's last skill and cleans disappeared gem providers" do
		installer.install
		FileUtils.rm_rf(File.join(provider_root, "context"))
		expect(installer.install[:skills]).to be == []
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing"))
		write_skill(provider_root, "ruby-testing", description: "Test projects.")
		installer.install
		subject.new(root: consumer_root, specifications: []).install
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing"))
	end
	
	it "preserves Cargo skills during a full Ruby refresh" do
		cargo = File.join(consumer_root, ".agents/skills/cargo-workflow/SKILL.md")
		FileUtils.mkdir_p(File.dirname(cargo))
		File.write(cargo, "Cargo instructions")
		write_owner(File.dirname(cargo), "fake-gem", "2.0.0", ecosystem: "cargo")
		metadata = File.read(File.join(File.dirname(cargo), "SKILL.md"))
		installer.install
		expect(File.read(cargo)).to be == metadata
		expect(File.read(File.join(File.dirname(cargo), "SKILL.md"))).to be == metadata
	end
	
	it "refuses a matching name owned by Cargo even when the package names match" do
		path = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing")
		FileUtils.mkdir_p(path)
		write_owner(path, "fake-gem", "1.0.0", ecosystem: "cargo")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::ConflictError)
	end
	
	it "keeps refreshed instructions identifiable when resource copying fails" do
		installer.install
		ownership_path = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing/SKILL.md")
		destination = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing/SKILL.md")
		write_skill(provider_root, "ruby-testing", description: "Updated workflow.", body: "# Updated\n")
		FileUtils.mkdir_p(File.join(provider_root, "context/ruby-testing"))
		File.symlink("missing", File.join(provider_root, "context/ruby-testing/broken"))
		expect do
			installer.install
		end.to raise_exception(Agent::Context::InvalidError)
		expect(Agent::Context::Skills::Ownership.load(File.dirname(ownership_path))["package"]).to be == "fake-gem"
		expect(File.read(destination)).to be(:include?, "# Updated")
		File.unlink(File.join(provider_root, "context/ruby-testing/broken"))
		installer.install
		expect(File.read(destination)).to be(:include?, "# Updated")
	end
	
	it "accepts the common metadata limits and rejects overlong descriptions" do
		write_skill(provider_root, "a" * 55, description: "d" * 1024)
		expect(skill_definitions("fake-gem").length).to be == 2
		expect(skill_definitions("fake-gem").first.name.length).to be == 64
		write_skill(provider_root, "a" * 55, description: "d" * 1025)
		expect do
			skill_definitions("fake-gem")
		end.to raise_exception(Agent::Context::InvalidError)
	end
	
	it "includes the package prefix when validating installed name length" do
		write_skill(provider_root, "a" * 56, description: "Run workflow.")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::InvalidError)
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing"))
	end
	
	it "rejects nested skill declarations outside a skill resource directory" do
		context = File.join(provider_root, "context/nested")
		FileUtils.mkdir_p(context)
		File.write(File.join(context, "workflow.md"), "---\nmetadata:\n  type: skill\ndescription: Run workflow.\n---\n\n# Workflow\n")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::InvalidError)
		expect(File).not.to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing"))
	end
	
	it "trims descriptions before enforcing the shared character limit" do
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(context)
		metadata = {"metadata" => {"type" => "skill"}, "description" => "  #{"é" * 1024}  "}
		File.write(File.join(context, "workflow.md"), "#{metadata.to_yaml}---\n\n# Workflow\n")
		installer.install
		content = File.read(File.join(consumer_root, ".agents/skills/fake-gem-workflow/SKILL.md"))
		expect(skill_definitions("fake-gem").find{|skill| skill.name == "fake-gem-workflow"}.description).to be == "  #{"é" * 1024}  "
		expect(Agent::Context::Document.parse(content, "installed").frontmatter["description"]).to be == "  #{"é" * 1024}  "
	end
	
	it "keeps plain guides out of skills and rejects invalid context skill metadata" do
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(context)
		guide = File.join(context, "guide.md")
		File.write(guide, "# Plain Guide\n\nOrdinary guidance.\n")
		expect(skill_definitions("fake-gem").map(&:name)).to be == ["fake-gem-ruby-testing"]
		File.write(guide, "---\nmetadata:\n  type: skill\ndescription: [invalid\n---\n")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::InvalidError)
		write_skill(provider_root, "Bad_Name", description: "Invalid name.")
		File.delete(guide)
		expect do
			installer.install
		end.to raise_exception(Agent::Context::InvalidError)
	end
	
	it "refuses a reserved SKILL.md resource while retaining generated ownership" do
		installer.install
		context = File.join(provider_root, "context")
		FileUtils.mkdir_p(File.join(context, "workflow"))
		File.write(File.join(context, "workflow.md"), "---\nmetadata:\n  type: skill\ndescription: Run workflow.\n---\n")
		File.write(File.join(context, "workflow/SKILL.md"), "Conflicting instructions")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::InvalidError)
		expect(Agent::Context::Skills::Ownership.load(File.join(consumer_root, ".agents/skills/fake-gem-workflow"))["package"]).to be == "fake-gem"
		expect(File).to be(:exist?, File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing/SKILL.md"))
	end
	
	it "reserves generated instructions and copies other resource names" do
		installer.install
		resources = File.join(provider_root, "context/workflow")
		FileUtils.mkdir_p(resources)
		write_skill(provider_root, "workflow", description: "Run workflow.")
		["SKILL.md", "skill.MD"].each do |name|
			path = File.join(resources, name)
			[false, true].each do |directory|
				directory ? FileUtils.mkdir_p(path) : File.write(path, "Conflict")
				expect{installer.install}.to raise_exception(Agent::Context::InvalidError)
				expect(Agent::Context::Skills::Ownership.load(File.join(consumer_root, ".agents/skills/fake-gem-workflow"))["package"]).to be == "fake-gem"
				FileUtils.rm_rf(path)
			end
		end
		FileUtils.mkdir_p(File.join(resources, "references"))
		File.write(File.join(resources, "notes.txt"), "Opaque resource")
		installer.install
		expect(File.read(File.join(consumer_root, ".agents/skills/fake-gem-workflow/notes.txt"))).to be == "Opaque resource"
	end
	
	it "reports inaccessible ownership before changing installed files or exclusions" do
		system("git", "init", "--quiet", consumer_root, exception: true)
		installer.install
		skill_path = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing")
		previous = Dir.children(skill_path).to_h{|name| [name, File.read(File.join(skill_path, name))]}
		exclude = File.join(consumer_root, ".git/info/exclude")
		previous_exclude = File.read(exclude)
		write_skill(provider_root, "ruby-testing", description: "Updated workflow.")
		begin
			File.chmod(0o400, skill_path)
			expect{installer.install}.to raise_exception(Errno::EACCES)
		ensure
			File.chmod(0o700, skill_path)
		end
		expect(Dir.children(skill_path).to_h{|name| [name, File.read(File.join(skill_path, name))]}).to be == previous
		expect(File.read(exclude)).to be == previous_exclude
	end
	
	it "works without Git and reports malformed generated exclusion blocks" do
		mock(Open3).before(:capture2e){raise Errno::ENOENT, "Git unavailable"}
		expect(installer.install[:skills]).to be == ["fake-gem-ruby-testing"]
		mock(Open3).clear
		system("git", "init", "--quiet", consumer_root, exception: true)
		File.write(File.join(consumer_root, ".git/info/exclude"), "# BEGIN bake-agent-context\n")
		expect do
			installer.install
		end.to raise_exception(Agent::Context::InvalidError)
	end
	it "removes an incomplete instruction write and permits a retry" do
		destination = File.join(consumer_root, ".agents/skills/fake-gem-ruby-testing")
		mock(File).before(:write) do |path, *|
			raise Errno::ENOSPC if path == File.join(destination, "SKILL.md")
		end
		expect{installer.install}.to raise_exception(Errno::ENOSPC)
		expect(File).not.to be(:exist?, destination)
		mock(File).clear
		installer.install
		expect(Agent::Context::Skills::Ownership.load(destination)["package"]).to be == "fake-gem"
	end
	
	it "installs loaded documents alongside opaque ordinary files" do
		context = File.join(provider_root, "context")
		File.write(File.join(context, "a-guide.md"), "# Original\n")
		File.binwrite(File.join(context, "z-image.bin"), "\x00\xff".b)
		package = Agent::Context::Package.load(specifications.first)
		File.write(File.join(context, "a-guide.md"), "# Changed\n")
		destination = File.join(consumer_root, ".agents/context/fake-gem")
		package.install_files(destination)
		expect(File.read(File.join(destination, "a-guide.md"))).to be == "# Original\n"
		expect(File.binread(File.join(destination, "z-image.bin"))).to be == "\x00\xff".b
	end
	
end
