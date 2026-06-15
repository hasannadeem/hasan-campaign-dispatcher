require "rails_helper"

RSpec.describe Recipient, type: :model do
  it "requires a name and an email (mirroring the DB NOT NULL constraints)" do
    recipient = build(:recipient, name: nil, email: nil)

    expect(recipient).not_to be_valid
    expect(recipient.errors.attribute_names).to include(:name, :email)
  end

  it "defaults to queued status" do
    expect(create(:recipient).status).to eq("queued")
  end

  describe ".search" do
    it "matches name or email case-insensitively" do
      ada = create(:recipient, name: "Ada Lovelace", email: "ada@example.com")
      create(:recipient, name: "Grace Hopper", email: "grace@example.com")

      expect(Recipient.search("lovelace")).to contain_exactly(ada)
      expect(Recipient.search("ADA@EXAMPLE")).to contain_exactly(ada)
      expect(Recipient.search("")).to match_array(Recipient.all)
    end
  end
end
