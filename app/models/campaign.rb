class Campaign < ApplicationRecord
  has_many :recipients, dependent: :destroy

  attr_accessor :recipients_text

  enum :status, { pending: 0, processing: 1, completed: 2 }

  validates :title, presence: true

  accepts_nested_attributes_for :recipients

  after_update_commit :broadcast_progress, if: :saved_change_to_status?

  def broadcast_progress
    broadcast_replace_to self, target: progress_dom_id,
      partial: "campaigns/progress", locals: { campaign: self }
  end

  def progress_dom_id
    "campaign_#{id}_progress"
  end

  def sent_count
    recipients.sent.count
  end

  def processed_count
    recipients.where.not(status: :queued).count
  end

  def progress_percent
    return 0 if recipients_count.zero?

    (processed_count * 100.0 / recipients_count).round
  end
end
