require "rails_helper"

RSpec.describe "Campaigns", type: :request do
  describe "POST /campaigns" do
    let(:valid_params) do
      {
        campaign: {
          title: "Spring product reviews",
          recipients_text: "Ada Lovelace, ada@example.com\nGrace Hopper, grace@example.com"
        }
      }
    end

    it "creates the campaign and its recipients" do
      expect { post campaigns_path, params: valid_params }
        .to change(Campaign, :count).by(1)
        .and change(Recipient, :count).by(2)

      campaign = Campaign.last
      expect(campaign.title).to eq("Spring product reviews")
      expect(campaign.recipients.pluck(:name)).to contain_exactly("Ada Lovelace", "Grace Hopper")
      expect(response).to redirect_to(campaign)
    end

    it "ignores blank recipient lines" do
      params = { campaign: { title: "Reviews", recipients_text: "\nAda, ada@example.com\n   \n" } }

      post campaigns_path, params: params

      expect(Campaign.last.recipients.count).to eq(1)
    end

    it "re-renders the form when the title is missing" do
      expect { post campaigns_path, params: { campaign: { title: "" } } }
        .not_to change(Campaign, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /campaigns/:id/start" do
    it "enqueues the dispatch job and redirects" do
      campaign = create(:campaign, :with_recipients)

      expect { post start_campaign_path(campaign) }
        .to have_enqueued_job(DispatchCampaignJob).with(campaign)

      expect(response).to redirect_to(campaign)
    end
  end
end
