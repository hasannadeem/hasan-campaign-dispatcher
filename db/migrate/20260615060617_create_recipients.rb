class CreateRecipients < ActiveRecord::Migration[7.2]
  def change
    create_table :recipients do |t|
      t.references :campaign, null: false, foreign_key: true
      t.string :name, null: false
      t.string :contact, null: false
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_index :recipients, [ :campaign_id, :status ]
  end
end
