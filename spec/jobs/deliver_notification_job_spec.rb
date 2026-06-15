require "rails_helper"

RSpec.describe DeliverNotificationJob, type: :job do
  # Mock the simulated network latency so the suite runs instantly.
  before { allow_any_instance_of(described_class).to receive(:sleep) }

  it "marks the recipient sent and increments processed_count on success" do
    campaign = create(:campaign, :with_recipients, recipients_count: 2)
    recipient = campaign.recipients.first
    allow_any_instance_of(described_class).to receive(:delivery_failed?).and_return(false)

    described_class.perform_now(recipient.id)

    expect(recipient.reload).to be_sent
    expect(campaign.reload.processed_count).to eq(1)
    expect(campaign.failed_count).to eq(0)
  end

  it "marks the recipient failed and increments failed_count on a simulated failure" do
    campaign = create(:campaign, :with_recipients, recipients_count: 2)
    recipient = campaign.recipients.first
    allow_any_instance_of(described_class).to receive(:delivery_failed?).and_return(true)

    described_class.perform_now(recipient.id)

    expect(recipient.reload).to be_failed
    expect(campaign.reload.failed_count).to eq(1)
    expect(campaign.processed_count).to eq(0)
  end

  it "atomically completes the campaign once the final recipient is processed" do
    campaign = create(:campaign, :with_recipients, recipients_count: 2)
    campaign.processing! # precondition: the dispatch job has already started the run
    allow_any_instance_of(described_class).to receive(:delivery_failed?).and_return(false)

    campaign.recipients.each { |r| described_class.perform_now(r.id) }

    expect(campaign.reload).to be_completed
    expect(campaign.processed_count).to eq(2)
  end

  it "records a failure (not a crash) when the send raises, so the batch still finishes" do
    campaign = create(:campaign, :with_recipients, recipients_count: 1)
    campaign.processing! # precondition: the dispatch job has already started the run
    recipient = campaign.recipients.first
    allow_any_instance_of(described_class).to receive(:delivery_failed?).and_raise(StandardError)

    described_class.perform_now(recipient.id)

    expect(recipient.reload).to be_failed
    expect(campaign.reload).to be_completed
  end

  it "is idempotent — skips a recipient that has already reached a terminal state" do
    campaign = create(:campaign, :with_recipients, recipients_count: 1)
    recipient = campaign.recipients.first
    recipient.update_column(:status, Recipient.statuses[:sent])

    expect { described_class.perform_now(recipient.id) }
      .not_to change { campaign.reload.processed_count }
  end

  it "advances the counter exactly once across duplicate runs (double-dispatch safety)" do
    campaign = create(:campaign, :with_recipients, recipients_count: 1)
    campaign.processing!
    recipient = campaign.recipients.first
    allow_any_instance_of(described_class).to receive(:delivery_failed?).and_return(false)

    2.times { described_class.perform_now(recipient.id) }

    expect(recipient.reload).to be_sent
    expect(campaign.reload.processed_count).to eq(1)
  end
end
