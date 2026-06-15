require "rails_helper"

RSpec.describe Campaigns::CsvImporter do
  it "groups title,name,email rows into one campaign per distinct title" do
    csv = <<~CSV
      title,name,email
      Q1 Reviews,Ada Lovelace,ada@example.com
      Q1 Reviews,Grace Hopper,grace@example.com
      Spring Promo,Alan Turing,alan@example.com
    CSV

    result = nil
    expect { result = described_class.call(csv) }
      .to change(Campaign, :count).by(2)
      .and change(Recipient, :count).by(3)

    expect(result.campaigns_created).to eq(2)
    expect(result.recipients_created).to eq(3)
    expect(Campaign.find_by(title: "Q1 Reviews").recipients_count).to eq(2)
  end

  it "skips and counts rows missing a title or email" do
    csv = "title,name,email\nValid,Ada,ada@example.com\n,No Title,x@example.com\nNo Email,Bob,\n"

    result = described_class.call(csv)

    expect(result.campaigns_created).to eq(1)
    expect(result.recipients_created).to eq(1)
    expect(result.skipped_rows).to eq(2)
  end

  it "derives a name from the email when the name column is blank" do
    result = described_class.call("title,name,email\nPromo,,grace@example.com")

    expect(result.recipients_created).to eq(1)
    expect(Recipient.last.name).to eq("grace")
  end
end
