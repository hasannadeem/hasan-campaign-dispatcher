require "rails_helper"

RSpec.describe Recipient, type: :model do
  it "requires a name and contact" do
    recipient = build(:recipient, name: nil, contact: nil)

    expect(recipient).not_to be_valid
    expect(recipient.errors.attribute_names).to include(:name, :contact)
  end

  it "defaults to queued status" do
    expect(create(:recipient).status).to eq("queued")
  end
end
