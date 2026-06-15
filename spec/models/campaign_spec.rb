require "rails_helper"

RSpec.describe Campaign, type: :model do
  it "is invalid without a title" do
    expect(build(:campaign, title: nil)).not_to be_valid
  end

  it "defaults to pending status" do
    expect(create(:campaign).status).to eq("pending")
  end

  describe "#progress_percent" do
    it "returns 0 when there are no recipients" do
      expect(create(:campaign).progress_percent).to eq(0)
    end

    it "reflects the share of processed recipients" do
      campaign = create(:campaign, :with_recipients, recipients_count: 4)
      campaign.recipients.limit(1).update_all(status: :sent)

      expect(campaign.progress_percent).to eq(25)
    end
  end
end
