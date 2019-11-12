# frozen_string_literal: true

class CreateCommunitiesMealsJoinTable < ActiveRecord::Migration[4.2]
  def change
    remove_column :meals, :community_id

    create_table :invitations do |t|
      t.references :community, index: true, null: false
      t.references :meal, index: true, null: false
      t.foreign_key :communities
      t.foreign_key :meals
    end
  end
end
