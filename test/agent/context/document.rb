# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Shopify Inc.

require "agent/context/document"
require "agent/context/test_document"
require "tmpdir"
require "fileutils"

describe Agent::Context::Document do
	let(:directory) {Dir.mktmpdir}
	let(:path) {File.join(directory, "guide.md")}
	let(:document) {subject.load(path)}
	
	def around
		yield
	ensure
		FileUtils.rm_rf(directory)
	end
	
	it "reads native front matter with a YAML format hint and standard dates" do
		File.write(path, "--- yaml\ntitle: Metadata title\ndate: 2026-10-09\nupdated: 2026-10-09T12:30:00Z\n---\n\n# Actual Title\n\nFirst sentence. Second sentence.\n")
		expect(document.frontmatter["title"]).to be == "Metadata title"
		expect(document.frontmatter["date"]).to be == Date.new(2026, 10, 9)
		expect(document.frontmatter["updated"]).to be == Time.utc(2026, 10, 9, 12, 30)
	end
	
	it "preserves the body bytes and source file when front matter uses CRLF" do
		body = "\r\n# Guide\r\n\r\nUse  [reference][guide].\r\n\r\n~~~yaml\r\n---\r\nexample: unchanged\r\n---\r\n~~~\r\n\r\n[guide]: https://example.test\r\n"
		content = "---\ndescription: Explicit summary.\n---\n".gsub("\n", "\r\n") + body
		File.binwrite(path, content)
		expect(document.body).to be == body
		expect(File.binread(path)).to be == content
	end
	
	it "parses in-memory Markdown with thematic breaks and code examples" do
		content = "# Guide\n\n---\n\n~~~yaml\n---\ntype: skill\n---\n~~~\n"
		parsed = subject.parse(content, path)
		expect(parsed.frontmatter).to be == {}
		expect(parsed.body).to be == content
	end
	
	it "accepts empty front matter" do
		File.write(path, "---\n---\n# Guide\n")
		expect(document.frontmatter).to be == {}
		expect(document.body).to be == "# Guide\n"
	end
	
	it "rejects non-mapping metadata with the source path" do
		File.write(path, "---\n- invalid\n---\n# Guide\n")
		expect do
			document
		end.to raise_exception(Agent::Context::InvalidError, message: be(:include?, path))
	end
	
	it "rejects arbitrary Ruby objects in YAML metadata" do
		File.write(path, "---\nobject: !ruby/object:Object {}\n---\n# Guide\n")
		expect do
			document
		end.to raise_exception(Agent::Context::InvalidError, message: be(:include?, path))
	end
	
	it "edits native front matter while retaining the shared fixture body" do
		fixture = File.read(Agent::Context::TestDocument.path)
		["\n", "\r\n"].each do |ending|
			source = subject.parse(fixture.gsub("\n", ending), path)
			output = source.render(source.frontmatter.merge("license" => "Apache-2.0"))
			installed = subject.parse(output, path)
			expect(source.content).to be == fixture.gsub("\n", ending)
			expect(installed.body).to be == source.body
			expect(installed.frontmatter["license"]).to be == "Apache-2.0"
			expect(installed.metadata["author"]).to be == "Provider"
		end
	end
	
	it "writes the source loaded before the provider file changes" do
		File.write(path, "# Original\n")
		loaded = document
		File.write(path, "# Changed\n")
		destination = File.join(directory, "installed.md")
		loaded.write(destination)
		expect(File.read(destination)).to be == "# Original\n"
	end
	
	it "uses nested skill metadata and keeps other front matter languages opaque" do
		["--- json\ninvalid: [\n---\n", "--- yml\ninvalid: [\n---\n", "---\ntype: skill\n---\n"].each do |content|
			expect(subject.parse(content, path)).not.to be(:skill?)
		end
	end
	
	it "defaults absent or null metadata to an empty mapping" do
		["", "---\nmetadata: null\n---\n"].each do |content|
			expect(subject.parse(content, path).metadata).to be == {}
		end
	end
	
	it "recognizes skills and treats other metadata types as ordinary context" do
		[["skill", true], ["guide", false], [nil, false], [false, false]].each do |type, skill|
			content = {"metadata" => {"type" => type}}.to_yaml + "---\n"
			expect(subject.parse(content, path).skill?).to be == skill
		end
	end
	
end
