class AddRecipientsCountToCampaigns < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :recipients_count, :integer, null: false, default: 0
  end
end
