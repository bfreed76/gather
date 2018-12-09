# frozen_string_literal: true

module Meals
  class FormulasController < ApplicationController
    include Destructible

    before_action -> { nav_context(:meals, :formulas) }
    decorates_assigned :formulas, :formula
    helper_method :sample_formula

    def index
      authorize(sample_formula)
      @formulas = policy_scope(Formula).in_community(current_community)
        .with_meal_counts.deactivated_last.by_name
    end

    def new
      @formula = sample_formula
      if Formula.in_community(current_community).empty?
        @formula.is_default = true
        @force_default = true
      end
      authorize(@formula)
    end

    def show
      @formula = Formula.find(params[:id])
      authorize(@formula)
    end

    def edit
      @formula = Formula.find(params[:id])
      authorize(@formula)
      flash.now[:notice] = I18n.t("meals/formulas.cant_edit_notice") unless policy(@formula).update_calcs?
    end

    def create
      @formula = sample_formula
      @formula.assign_attributes(formula_params)
      authorize(@formula)
      if @formula.save
        flash[:success] = "Formula created successfully."
        redirect_to(meals_formulas_path)
      else
        render(:new)
      end
    end

    def update
      @formula = Formula.find(params[:id])
      authorize(@formula)
      if @formula.update(formula_params)
        flash[:success] = "Formula updated successfully."
        redirect_to(meals_formulas_path)
      else
        render(:edit)
      end
    end

    protected

    def klass
      Formula
    end

    private

    def sample_formula
      Formula.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def formula_params
      params.require(:meals_formula).permit(policy(@formula).permitted_attributes)
    end
  end
end
