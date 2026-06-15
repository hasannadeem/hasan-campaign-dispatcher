module Campaigns
  # Recovery loop: re-queues only the failed recipients of a completed campaign,
  # rolls the campaign back to `processing`, fixes the counter caches, and
  # re-triggers the fan-out. The whole reset runs under a row lock so it can't
  # race a straggling worker's completion transition.
  class RetryFailedService
    def initialize(campaign)
      @campaign = campaign
    end

    def call
      requeued_ids = reset_failed_recipients
      return false unless requeued_ids

      # Broadcast the re-queued rows (outside the lock) so passive observers see
      # them flip back to queued immediately — update_all skipped their callbacks.
      # Done before enqueuing so no worker can flip a row before we paint it.
      broadcast_requeued_rows(requeued_ids)
      DispatchCampaignJob.perform_later(@campaign.id)
      true
    end

    private

    def reset_failed_recipients
      @campaign.with_lock do
        return false unless @campaign.retryable?

        failed = @campaign.recipients.failed
        requeued_ids = failed.pluck(:id)

        # Single-statement reset (no N+1, no callbacks). We re-broadcast the rows
        # ourselves in #call rather than pay per-row callbacks here.
        failed.update_all(status: Recipient.statuses[:queued], updated_at: Time.current)

        # Every failed recipient was just re-queued, so none remain failed —
        # set the counter to 0 outright (drift-proof vs. decrementing).
        @campaign.update!(status: :processing, failed_count: 0)

        requeued_ids
      end
    end

    def broadcast_requeued_rows(recipient_ids)
      @campaign.recipients.where(id: recipient_ids).find_each do |recipient|
        recipient.broadcast_replace_to(@campaign)
      end
    end
  end
end
