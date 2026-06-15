class AddProgressCountersToCampaigns < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :processed_count, :integer, default: 0, null: false
    add_column :campaigns, :failed_count, :integer, default: 0, null: false
  end
end
