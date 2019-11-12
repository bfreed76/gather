# frozen_string_literal: true

class AddReminderCountToAssignments < ActiveRecord::Migration[4.2]
  def up
    add_column :assignments, :reminder_count, :integer, null: false, default: 0
    Assignment.where("notified = 't'").update_all("reminder_count = 1")
    remove_column :assignments, :notified
  end
end
