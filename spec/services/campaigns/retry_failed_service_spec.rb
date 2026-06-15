require "rails_helper"

RSpec.describe Campaigns::RetryFailedService do
  def completed_campaign_with(sent:, failed:)
    campaign = create(:campaign, :with_recipients, recipients_count: sent + failed, status: :completed)
    campaign.update_columns(processed_count: sent, failed_count: failed)
    recipients = campaign.recipients.order(:id).to_a
    recipients.first(sent).each { |r| r.update_column(:status, Recipient.statuses[:sent]) }
    recipients.last(failed).each { |r| r.update_column(:status, Recipient.statuses[:failed]) }
    campaign
  end

  it "re-queues only the failed recipients, reopens the campaign, fixes counters, and re-dispatches" do
    campaign = completed_campaign_with(sent: 1, failed: 2)

    expect { expect(described_class.new(campaign).call).to be(true) }
      .to have_enqueued_job(DispatchCampaignJob).with(campaign.id)

    campaign.reload
    expect(campaign).to be_processing
    expect(campaign.failed_count).to eq(0)
    expect(campaign.processed_count).to eq(1)
    expect(campaign.recipients.queued.count).to eq(2)
    expect(campaign.recipients.sent.count).to eq(1)
  end

  it "re-broadcasts each re-queued row so passive observers update live" do
    campaign = completed_campaign_with(sent: 1, failed: 2)

    broadcast_ids = []
    allow_any_instance_of(Recipient).to receive(:broadcast_replace_to) { |recipient| broadcast_ids << recipient.id }

    described_class.new(campaign).call

    expect(broadcast_ids).to match_array(campaign.recipients.queued.pluck(:id))
  end

  it "does nothing and returns false when the campaign has no failures" do
    campaign = completed_campaign_with(sent: 2, failed: 0)

    expect { expect(described_class.new(campaign).call).to be(false) }
      .not_to have_enqueued_job(DispatchCampaignJob)

    expect(campaign.reload).to be_completed
  end
end
