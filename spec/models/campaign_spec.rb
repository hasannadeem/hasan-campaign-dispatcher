require "rails_helper"

RSpec.describe Campaign, type: :model do
  it "is invalid without a title" do
    expect(build(:campaign, title: nil)).not_to be_valid
  end

  it "defaults to pending status" do
    expect(create(:campaign).status).to eq("pending")
  end

  describe "status transition guardrail" do
    it "allows the forward path pending -> processing -> completed" do
      campaign = create(:campaign)

      expect(campaign.processing!).to be(true)
      expect(campaign.completed!).to be(true)
    end

    it "forbids skipping straight from pending to completed" do
      campaign = create(:campaign)

      expect { campaign.completed! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(campaign.reload).to be_pending
    end

    it "allows the completed -> processing recovery edge used by retries" do
      campaign = create(:campaign, status: :completed)

      expect(campaign.processing!).to be(true)
    end
  end

  describe "#progress_percent" do
    it "returns 0 when there are no recipients" do
      expect(create(:campaign).progress_percent).to eq(0)
    end

    it "is derived from the processed and failed counter caches" do
      campaign = create(:campaign, :with_recipients, recipients_count: 4)
      campaign.update!(processed_count: 2, failed_count: 1)

      expect(campaign.progress_percent).to eq(75)
    end
  end

  describe "#retryable?" do
    it "is true only for a completed campaign that has failures" do
      expect(create(:campaign, status: :completed, failed_count: 2)).to be_retryable
      expect(create(:campaign, status: :completed, failed_count: 0)).not_to be_retryable
      expect(create(:campaign, status: :processing, failed_count: 2)).not_to be_retryable
    end
  end

  describe "#render_body_for" do
    it "substitutes the {{name}} merge tag with the recipient's name" do
      campaign = build(:campaign, body: "Hi {{name}}, thanks!")
      recipient = build(:recipient, name: "Ada")

      expect(campaign.render_body_for(recipient)).to eq("Hi Ada, thanks!")
    end

    it "is a blank string when the body is nil" do
      expect(build(:campaign, body: nil).render_body_for(build(:recipient))).to eq("")
    end
  end

  describe ".search" do
    it "matches titles case-insensitively and returns all for a blank query" do
      spring = create(:campaign, title: "Spring Reviews")
      create(:campaign, title: "Winter Promo")

      expect(Campaign.search("spring")).to contain_exactly(spring)
      expect(Campaign.search("")).to match_array(Campaign.all)
    end
  end
end
