# frozen_string_literal: true

class CreateResources < ActiveRecord::Migration[4.2]
  def change
    create_table :resources do |t|
      t.string :name, limit: 24, null: false
      t.references :community, null: false, index: true
      t.foreign_key :communities
      t.attachment :photo
      t.boolean :meal_hostable, null: false, default: false

      t.timestamps null: false
    end
  end
end
