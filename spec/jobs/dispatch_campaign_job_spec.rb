require "rails_helper"

RSpec.describe DispatchCampaignJob, type: :job do
  it "moves the campaign to processing and fans out one worker per queued recipient" do
    campaign = create(:campaign, :with_recipients, recipients_count: 3)

    expect { described_class.perform_now(campaign.id) }
      .to change { campaign.reload.status }.from("pending").to("processing")
      .and have_enqueued_job(DeliverNotificationJob).exactly(3).times
  end

  it "passes only the recipient id (a primitive) to the child worker" do
    campaign = create(:campaign, :with_recipients, recipients_count: 1)
    recipient = campaign.recipients.first

    expect { described_class.perform_now(campaign.id) }
      .to have_enqueued_job(DeliverNotificationJob).with(recipient.id)
  end

  it "does not fan out a campaign that is already completed (lock guard)" do
    campaign = create(:campaign, :with_recipients, recipients_count: 2, status: :completed)

    expect { described_class.perform_now(campaign.id) }
      .not_to have_enqueued_job(DeliverNotificationJob)
  end

  it "completes immediately when there is nothing to dispatch" do
    campaign = create(:campaign)

    expect { described_class.perform_now(campaign.id) }
      .to change { campaign.reload.status }.from("pending").to("completed")
  end
end
