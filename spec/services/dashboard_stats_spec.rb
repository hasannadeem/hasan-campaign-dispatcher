require "rails_helper"

RSpec.describe DashboardStats do
  it "aggregates campaign metrics from the counter caches" do
    create(:campaign, :with_recipients, recipients_count: 3, status: :processing)
      .update_columns(processed_count: 2, failed_count: 1)
    create(:campaign, :with_recipients, recipients_count: 2, status: :completed)
      .update_columns(processed_count: 2, failed_count: 0)

    stats = described_class.new

    expect(stats.total_campaigns).to eq(2)
    expect(stats.active_campaigns).to eq(1)      # one processing
    expect(stats.total_recipients).to eq(5)      # 3 + 2
    expect(stats.emails_sent).to eq(4)           # 2 + 2
    expect(stats.emails_failed).to eq(1)
  end

  it "returns zeros with no campaigns" do
    stats = described_class.new

    expect(stats.total_campaigns).to eq(0)
    expect(stats.total_recipients).to eq(0)
    expect(stats.emails_sent).to eq(0)
  end
end
