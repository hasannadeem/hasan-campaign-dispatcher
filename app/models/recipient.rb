class Recipient < ApplicationRecord
  belongs_to :campaign, counter_cache: true

  enum :status, { queued: 0, sent: 1, failed: 2 }

  validates :name, :contact, presence: true

  after_update_commit :broadcast_status_change, if: :saved_change_to_status?

  private

  def broadcast_status_change
    broadcast_replace_to campaign, target: self, partial: "recipients/recipient", locals: { recipient: self }
    campaign.broadcast_progress
  end
end
