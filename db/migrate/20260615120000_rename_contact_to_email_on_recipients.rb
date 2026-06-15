class RenameContactToEmailOnRecipients < ActiveRecord::Migration[7.2]
  def change
    rename_column :recipients, :contact, :email
  end
end
