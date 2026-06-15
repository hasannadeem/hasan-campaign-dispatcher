require "rails_helper"

RSpec.describe DispatchCampaignJob, type: :job do
  before { allow_any_instance_of(described_class).to receive(:sleep) }

  it "moves the campaign from pending to completed" do
    campaign = create(:campaign, :with_recipients, recipients_count: 2)
    allow_any_instance_of(described_class).to receive(:delivery_outcome).and_return(:sent)

    expect { described_class.perform_now(campaign) }
      .to change { campaign.reload.status }.from("pending").to("completed")
  end

  it "marks each recipient as sent on a successful delivery" do
    campaign = create(:campaign, :with_recipients, recipients_count: 3)
    allow_any_instance_of(described_class).to receive(:delivery_outcome).and_return(:sent)

    described_class.perform_now(campaign)

    expect(campaign.recipients.pluck(:status).uniq).to eq([ "sent" ])
  end

  it "marks a recipient as failed when the delivery raises" do
    campaign = create(:campaign, :with_recipients, recipients_count: 1)
    allow_any_instance_of(described_class).to receive(:delivery_outcome).and_raise(StandardError)

    described_class.perform_now(campaign)

    expect(campaign.recipients.first).to be_failed
  end
end
