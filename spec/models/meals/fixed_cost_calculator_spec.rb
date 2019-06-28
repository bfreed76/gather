# frozen_string_literal: true

require "rails_helper"

describe Meals::FixedCostCalculator do
  let(:formula) do
    build(:meal_formula,
      meal_calc_type: "fixed",
      pantry_calc_type: pantry_calc_type,
      pantry_fee: pantry_fee,
      adult_meat: 4,
      adult_veg: 3,
      little_kid_veg: 0)
  end
  let(:meal) { build(:meal, formula: formula) }
  let(:calculator) { Meals::FixedCostCalculator.new(meal) }

  before do
    meal.build_cost
    allow(Meals::Signup).to receive(:totals_for_meal).and_return(
      "adult_meat" => 9, "adult_veg" => 3, "little_kid_veg" => 2
    )
  end

  context "with fixed pantry_calc_type" do
    let(:pantry_calc_type) { "fixed" }
    let(:pantry_fee) { 0.5 }

    describe "price_for" do
      it "should be correct" do
        expect(calculator.price_for("adult_meat")).to eq(4.5)
        expect(calculator.price_for("adult_veg")).to eq(3.5)
        expect(calculator.price_for("little_kid_veg")).to eq(0)
      end
    end

    describe "max_ingredient_cost" do
      it "should be correct" do
        expect(calculator.max_ingredient_cost).to eq(45)
      end
    end
  end

  context "with ratio pantry_calc_type" do
    let(:pantry_calc_type) { "ratio" }
    let(:pantry_fee) { 0.1 }

    describe "price_for" do
      it "should be correct" do
        expect(calculator.price_for("adult_meat")).to eq(4.4)
        expect(calculator.price_for("adult_veg")).to eq(3.3)
        expect(calculator.price_for("little_kid_veg")).to eq(0)
      end
    end
  end
end
