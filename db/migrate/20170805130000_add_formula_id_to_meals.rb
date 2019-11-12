# frozen_string_literal: true

class AddFormulaIdToMeals < ActiveRecord::Migration[4.2]
  def change
    add_column :meals, :formula_id, :integer
    add_index :meals, :formula_id
    add_foreign_key :meals, :meals_formulas, column: :formula_id
  end
end
