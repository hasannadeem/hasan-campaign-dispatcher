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

    it "accepts a comma-less line as a bare email, defaulting the name" do
      params = { campaign: { title: "Reviews", recipients_text: "grace@example.com" } }

      post campaigns_path, params: params

      recipient = Campaign.last.recipients.sole
      expect(recipient.email).to eq("grace@example.com")
      expect(recipient.name).to eq("grace")
    end

    it "re-renders the form when the title is missing" do
      expect { post campaigns_path, params: { campaign: { title: "" } } }
        .not_to change(Campaign, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "POST /campaigns/:id/start" do
    it "enqueues the dispatch job with the campaign id (a primitive) and redirects" do
      campaign = create(:campaign, :with_recipients)

      expect { post start_campaign_path(campaign) }
        .to have_enqueued_job(DispatchCampaignJob).with(campaign.id)

      expect(response).to redirect_to(campaign)
    end

    it "does not re-dispatch a campaign that is not pending" do
      campaign = create(:campaign, :with_recipients, status: :processing)

      expect { post start_campaign_path(campaign) }
        .not_to have_enqueued_job(DispatchCampaignJob)

      expect(response).to redirect_to(campaign)
    end
  end

  describe "POST /campaigns/:id/retry_failed" do
    it "re-dispatches when there are failed recipients" do
      campaign = create(:campaign, :with_recipients, recipients_count: 2, status: :completed)
      campaign.update_columns(processed_count: 1, failed_count: 1)
      campaign.recipients.order(:id).first.update_column(:status, Recipient.statuses[:sent])
      campaign.recipients.order(:id).last.update_column(:status, Recipient.statuses[:failed])

      expect { post retry_failed_campaign_path(campaign) }
        .to have_enqueued_job(DispatchCampaignJob).with(campaign.id)

      expect(response).to redirect_to(campaign)
    end

    it "redirects with an alert when there is nothing to retry" do
      campaign = create(:campaign, :with_recipients, recipients_count: 2, status: :completed)

      expect { post retry_failed_campaign_path(campaign) }
        .not_to have_enqueued_job(DispatchCampaignJob)

      expect(response).to redirect_to(campaign)
      expect(flash[:alert]).to be_present
    end
  end

  describe "POST /campaigns with a body and CSV upload" do
    def csv_upload(content, filename: "recipients.csv")
      Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: filename)
    end

    it "stores the message body" do
      post campaigns_path, params: { campaign: { title: "Reviews", body: "Hi {{name}}!", recipients_text: "Ada, ada@example.com" } }

      expect(Campaign.last.body).to eq("Hi {{name}}!")
    end

    it "creates recipients from an uploaded CSV instead of the textarea" do
      params = { campaign: { title: "From CSV", recipients_csv: csv_upload("name,email\nAda,ada@example.com\nGrace,grace@example.com") } }

      expect { post campaigns_path, params: params }.to change(Recipient, :count).by(2)
      expect(Campaign.last.recipients.pluck(:email)).to contain_exactly("ada@example.com", "grace@example.com")
    end
  end

  describe "GET /campaigns with filters" do
    it "filters the campaign list by query and status" do
      create(:campaign, title: "Spring Reviews", status: :processing)
      create(:campaign, title: "Winter Promo", status: :completed)

      get root_path, params: { q: "spring" }
      expect(response.body).to include("Spring Reviews")
      expect(response.body).not_to include("Winter Promo")

      get root_path, params: { status: "completed" }
      expect(response.body).to include("Winter Promo")
      expect(response.body).not_to include("Spring Reviews")
    end
  end

  describe "GET /campaigns/:id with recipient filters" do
    it "filters the recipient list by query and status" do
      campaign = create(:campaign)
      campaign.recipients.create!(name: "Ada Lovelace", email: "ada@example.com", status: :sent)
      campaign.recipients.create!(name: "Grace Hopper", email: "grace@example.com", status: :failed)

      get campaign_path(campaign), params: { rq: "lovelace" }
      expect(response.body).to include("ada@example.com")
      expect(response.body).not_to include("grace@example.com")

      get campaign_path(campaign), params: { rstatus: "failed" }
      expect(response.body).to include("grace@example.com")
      expect(response.body).not_to include("ada@example.com")
    end
  end

  describe "campaign CSV import" do
    def csv_upload(content)
      Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "campaigns.csv")
    end

    it "renders the import form" do
      get import_campaigns_path
      expect(response).to have_http_status(:ok)
    end

    it "imports campaigns and recipients from an uploaded file" do
      csv = "title,name,email\nQ1,Ada,ada@example.com\nQ1,Grace,grace@example.com\nQ2,Alan,alan@example.com"

      expect { post import_campaigns_path, params: { file: csv_upload(csv) } }
        .to change(Campaign, :count).by(2)
        .and change(Recipient, :count).by(3)

      expect(response).to redirect_to(root_path)
      expect(flash[:notice]).to include("2 campaign")
    end

    it "re-renders with an alert when no file is provided" do
      post import_campaigns_path

      expect(response).to have_http_status(:unprocessable_content)
      expect(flash[:alert]).to be_present
    end
  end
end
