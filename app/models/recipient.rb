class Recipient < ApplicationRecord
  belongs_to :campaign, counter_cache: true

  enum :status, { queued: 0, sent: 1, failed: 2 }

  # Mirror the DB's NOT NULL constraints at the model layer so invalid records
  # surface as graceful validation errors rather than raw NotNullViolations.
  validates :name, :email, presence: true

  # Case-insensitive search across name and email; blank query is a no-op.
  scope :search, ->(query) { where("name ILIKE :q OR email ILIKE :q", q: "%#{sanitize_sql_like(query)}%") if query.present? }

  # Each recipient row owns its own state: when its status changes it replaces
  # just its own <li> on the campaign's stream. The aggregate metric panel is
  # broadcast separately by the campaign (driven by its counter caches).
  after_update_commit :broadcast_row, if: :saved_change_to_status?

  private

  def broadcast_row
    broadcast_replace_to campaign
  end
end
