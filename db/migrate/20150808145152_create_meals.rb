# frozen_string_literal: true

class CreateMeals < ActiveRecord::Migration[4.2]
  def change
    create_table :meals do |t|
      t.string :title, null: false
      t.datetime :served_at, null: false, index: true
      t.text :entrees
      t.text :side
      t.text :kids
      t.text :dessert
      t.text :notes
      t.text :allergens, null: false, default: "[]"
      t.references :community, null: false, index: true
      t.foreign_key :communities
      t.integer :capacity, null: false

      t.timestamps null: false
    end
  end
end
