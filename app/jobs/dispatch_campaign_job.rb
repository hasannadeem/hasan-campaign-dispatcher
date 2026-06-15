class DispatchCampaignJob < ApplicationJob
  queue_as :default

  def perform(campaign)
    campaign.processing!

    campaign.recipients.queued.find_each { |recipient| deliver(recipient) }

    campaign.completed!
  end

  private

  def deliver(recipient)
    sleep(rand(1..3))
    recipient.update!(status: delivery_outcome)
  rescue StandardError => e
    recipient.update!(status: :failed)
    Rails.logger.error("Delivery failed for recipient ##{recipient.id}: #{e.class} - #{e.message}")
  end

  def delivery_outcome
    rand(10).zero? ? :failed : :sent
  end
end
