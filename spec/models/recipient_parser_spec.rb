require "rails_helper"

RSpec.describe RecipientParser do
  it "splits each line on the first comma into name and email" do
    parsed = described_class.parse("Ada Lovelace, ada@example.com")

    expect(parsed.map(&:name)).to eq([ "Ada Lovelace" ])
    expect(parsed.map(&:email)).to eq([ "ada@example.com" ])
  end

  it "splits on the first comma only (name before it, everything after is the email)" do
    parsed = described_class.parse("Ada, ada@example.com, ignored")

    expect(parsed.first.name).to eq("Ada")
    expect(parsed.first.email).to eq("ada@example.com, ignored")
  end

  it "treats a comma-less line as a bare email and derives the name from the local part" do
    parsed = described_class.parse("grace@example.com")

    expect(parsed.first.name).to eq("grace")
    expect(parsed.first.email).to eq("grace@example.com")
  end

  it "trims whitespace and skips blank lines" do
    parsed = described_class.parse("\n  Ada , ada@example.com \n   \n")

    expect(parsed.size).to eq(1)
    expect(parsed.first.name).to eq("Ada")
    expect(parsed.first.email).to eq("ada@example.com")
  end
end
