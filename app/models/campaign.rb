class Campaign < ApplicationRecord
  has_many :recipients, dependent: :destroy

  attr_accessor :recipients_text

  enum :status, { pending: 0, processing: 1, completed: 2 }

  validates :title, presence: true
  validate :enforce_status_transition, if: :will_save_change_to_status?, on: :update

  # Case-insensitive title search; a blank query is a no-op (returns all).
  scope :search, ->(query) { where("title ILIKE ?", "%#{sanitize_sql_like(query)}%") if query.present? }

  # The dashboard's global metric panel re-renders whenever the campaign row
  # changes — i.e. on every counter increment and on status changes — so the
  # progress bar and counts stay live without a full page load.
  after_update_commit :broadcast_metrics

  # Allowed status edges. The forward path is pending -> processing -> completed;
  # completed -> processing is the single recovery edge used by the retry loop.
  STATUS_TRANSITIONS = {
    "pending"    => %w[processing],
    "processing" => %w[completed],
    "completed"  => %w[processing]
  }.freeze

  # Counter-cache backed progress — no GROUP BY, no per-row COUNT, no N+1.
  def finished_count
    processed_count + failed_count
  end

  def all_processed?
    finished_count >= recipients_count
  end

  def progress_percent
    return 0 if recipients_count.zero?

    (finished_count * 100.0 / recipients_count).round
  end

  # The retry loop only makes sense once a campaign is done and some sends failed.
  def retryable?
    completed? && failed_count.positive?
  end

  # Renders the campaign body for a recipient, substituting merge tags. Today
  # that's just {{name}}; the seam is here to grow (e.g. {{email}}) cheaply.
  def render_body_for(recipient)
    body.to_s.gsub("{{name}}", recipient.name.to_s)
  end

  def metrics_dom_id
    ActionView::RecordIdentifier.dom_id(self, :metrics)
  end

  def broadcast_metrics
    broadcast_replace_to self,
      target: metrics_dom_id,
      partial: "campaigns/metrics",
      locals: { campaign: self }
  end

  private

  def enforce_status_transition
    from = status_was
    return if from.nil?

    allowed = STATUS_TRANSITIONS.fetch(from, [])
    return if allowed.include?(status)

    errors.add(:status, "cannot transition from #{from} to #{status}")
  end
end
