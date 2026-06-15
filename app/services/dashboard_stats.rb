# Aggregate metrics for the dashboard header cards. Every figure is read from
# the campaigns table's counter-cache columns (SUM/COUNT over one table) — no
# recipients scan, no N+1.
class DashboardStats
  def total_campaigns
    Campaign.count
  end

  def active_campaigns
    Campaign.processing.count
  end

  def total_recipients
    Campaign.sum(:recipients_count)
  end

  def emails_sent
    Campaign.sum(:processed_count)
  end

  def emails_failed
    Campaign.sum(:failed_count)
  end
end
