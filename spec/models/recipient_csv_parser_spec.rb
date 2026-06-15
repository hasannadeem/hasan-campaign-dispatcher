require "rails_helper"

RSpec.describe RecipientCsvParser do
  it "parses name,email rows" do
    parsed = described_class.parse("Ada Lovelace,ada@example.com\nGrace Hopper,grace@example.com")

    expect(parsed.map(&:name)).to eq([ "Ada Lovelace", "Grace Hopper" ])
    expect(parsed.map(&:email)).to eq([ "ada@example.com", "grace@example.com" ])
  end

  it "skips a name,email header row" do
    parsed = described_class.parse("name,email\nAda,ada@example.com")

    expect(parsed.size).to eq(1)
    expect(parsed.first.email).to eq("ada@example.com")
  end

  it "derives the name from the local part when only an email is given" do
    parsed = described_class.parse("grace@example.com")

    expect(parsed.first.name).to eq("grace")
    expect(parsed.first.email).to eq("grace@example.com")
  end

  it "trims whitespace and skips blank lines" do
    parsed = described_class.parse("\nAda , ada@example.com \n\n")

    expect(parsed.size).to eq(1)
    expect(parsed.first.name).to eq("Ada")
  end

  it "returns no recipients for a malformed file rather than raising" do
    expect(described_class.parse('a,"unterminated')).to eq([])
  end
end
