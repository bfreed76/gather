class RenameMealsSubTables < ActiveRecord::Migration
  def change
    rename_table :meals_formulas, :meal_formulas
    rename_table :meals_costs, :meal_costs
    rename_table :meals_messages, :meal_messages
  end
end
