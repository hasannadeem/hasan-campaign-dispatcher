class DeliverNotificationJob < ApplicationJob
  queue_as :delivery

  # Atomic per-recipient worker. Simulates a single notification send, then
  # records the outcome and advances the campaign's counter caches inside one
  # locked transaction so concurrent workers can't corrupt the totals or race
  # the final `completed` transition.
  def perform(recipient_id)
    recipient = Recipient.find_by(id: recipient_id)
    # Idempotency guard: a re-run (Sidekiq retry, duplicate fan-out) skips any
    # recipient that has already reached a terminal state.
    return unless recipient&.queued?

    record_outcome(recipient, simulate_delivery(recipient_id))
  end

  private

  def simulate_delivery(recipient_id)
    sleep(rand(1..3))
    delivery_failed? ? :failed : :sent
  rescue StandardError => e
    # A raised send must never abort the batch — record it as a failure so the
    # campaign can still reach `completed`.
    Rails.logger.error("Delivery raised for recipient ##{recipient_id}: #{e.class} - #{e.message}")
    :failed
  end

  # Simulated 10% infrastructure failure rate. Stubbable seam for specs.
  def delivery_failed?
    rand(100) < 10
  end

  def record_outcome(recipient, status)
    campaign = recipient.campaign

    # The campaign row lock serializes all of this campaign's child workers, so
    # the recipient claim (reload + queued? check) is atomic with its update and
    # the counter increment. A duplicate worker — from a double-clicked dispatch
    # that fanned out twice — reloads a non-queued recipient and bails, so a
    # recipient is processed, and its counter advanced, exactly once.
    campaign.with_lock do
      next unless recipient.reload.queued?

      recipient.update!(status: status)
      campaign[counter_for(status)] += 1
      campaign.status = :completed if !campaign.completed? && campaign.all_processed?
      campaign.save!
    end
  end

  def counter_for(status)
    status.to_sym == :sent ? :processed_count : :failed_count
  end
end
