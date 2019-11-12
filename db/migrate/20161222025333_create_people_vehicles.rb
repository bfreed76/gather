# frozen_string_literal: true

class CreatePeopleVehicles < ActiveRecord::Migration[4.2]
  def change
    create_table :people_vehicles do |t|
      t.references :household, index: true, foreign_key: true
      t.string :make
      t.string :model
      t.string :color

      t.timestamps null: false
    end
  end
end
