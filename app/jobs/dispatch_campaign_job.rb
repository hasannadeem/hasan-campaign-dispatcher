class DispatchCampaignJob < ApplicationJob
  queue_as :dispatch

  # Fan-out master. Acquires a row lock (so a double-clicked "Dispatch" can only
  # flip the campaign into `processing` once), then enqueues one atomic child
  # worker per queued recipient. Only primitive IDs cross the Sidekiq boundary.
  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)

    recipient_ids =
      campaign.with_lock do
        campaign.processing! if campaign.pending?
        # Guard: nothing to fan out unless the campaign is actively processing.
        next [] unless campaign.processing?

        # Re-querying `queued` keeps retries idempotent and lets the retry loop
        # reuse this same job for the recipients it just re-queued.
        campaign.recipients.queued.order(:id).pluck(:id)
      end

    recipient_ids.each { |id| DeliverNotificationJob.perform_later(id) }

    # A campaign with nothing left to send completes immediately.
    complete_if_finished(campaign) if recipient_ids.empty?
  end

  private

  def complete_if_finished(campaign)
    campaign.with_lock do
      campaign.update!(status: :completed) if campaign.processing? && campaign.all_processed?
    end
  end
end
