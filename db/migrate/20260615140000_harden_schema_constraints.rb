class HardenSchemaConstraints < ActiveRecord::Migration[7.2]
  def up
    # 1. DB-level enum range guards — defense in depth beyond the Rails enums,
    #    so a raw UPDATE / update_all can never store an out-of-range status.
    add_check_constraint :campaigns,  "status IN (0, 1, 2)", name: "campaigns_status_range"
    add_check_constraint :recipients, "status IN (0, 1, 2)", name: "recipients_status_range"

    # 2. Drop the redundant single-column index: the composite
    #    (campaign_id, status) index already serves campaign_id-only lookups
    #    (and the FK cascade) via its leftmost prefix.
    remove_index :recipients, name: "index_recipients_on_campaign_id"

    # 3. Promote the FK to ON DELETE CASCADE as a DB-level backstop against
    #    orphans. App-level deletes still flow through dependent: :destroy
    #    (preserving callbacks/broadcasts); cascade only fires on raw deletes.
    remove_foreign_key :recipients, :campaigns
    add_foreign_key :recipients, :campaigns, on_delete: :cascade
  end

  def down
    remove_foreign_key :recipients, :campaigns
    add_foreign_key :recipients, :campaigns

    add_index :recipients, :campaign_id, name: "index_recipients_on_campaign_id"

    remove_check_constraint :recipients, name: "recipients_status_range"
    remove_check_constraint :campaigns,  name: "campaigns_status_range"
  end
end
