class AddBodyToCampaigns < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :body, :text
  end
end
