class MealsController < ApplicationController
  include MealShowable, Lensable

  before_action :init_meal, only: :new
  before_action :create_worker_change_notifier, only: :update
  before_action -> { nav_context(:meals) }

  def index
    nav_context(:meals, :meals)
    prepare_lens(:search, :time, :community)

    authorize Meal
    load_meals
    load_communities
  end

  def jobs
    authorize Meal, :index?
    nav_context(:meals, :jobs)
    prepare_lens(:user, :time, :community)
    @user = User.find(lens[:user]) if lens[:user].present?
    load_meals
    load_communities
  end

  def show
    @meal = Meal.find(params[:id])
    authorize @meal

    # Don't want the singup form to get cached
    set_no_cache unless @meal.in_past?

    @signup = Signup.for(current_user, @meal)
    @account = current_user.account_for(@meal.host_community)
    load_signups
    load_prev_next_meal
  end

  def reports
    authorize Meal, :reports?
    nav_context(:meals, :reports)
    prepare_lens(:community)
    load_community_from_lens_with_default
    @report = Meals::Report.new(@community)
    @communities = Community.by_name_with_first(@community).to_a
  end

  def new
    authorize @meal
    @min_date = Date.today.strftime("%Y-%m-%d")
    prep_form_vars
  end

  def edit
    @meal = Meal.find(params[:id])
    authorize @meal
    @min_date = nil
    @notify_on_worker_change = !policy(@meal).administer?
    prep_form_vars
  end

  def create
    @meal = Meal.new(
      host_community_id: current_user.community_id,
      creator: current_user
    )
    @meal.assign_attributes(permitted_attributes(@meal))
    @meal.sync_reservations
    authorize @meal
    if @meal.save
      flash[:success] = "Meal created successfully."
      redirect_to meals_path
    else
      set_validation_error_notice
      prep_form_vars
      render :new
    end
  end

  def update
    @meal = Meal.find(params[:id])
    authorize @meal
    @meal.assign_attributes(permitted_attributes(@meal))
    @meal.sync_reservations
    if @meal.save
      flash[:success] = "Meal updated successfully."
      @worker_change_notifier.try(:check_and_send!)
      redirect_to meals_path
    else
      set_validation_error_notice
      prep_form_vars
      render :edit
    end
  end

  def close
    @meal = Meal.find(params[:id])
    authorize @meal
    @meal.close!
    flash[:success] = "Meal closed successfully."
    redirect_to(meals_path)
  end

  def finalize
    @meal = Meal.find(params[:id])
    authorize @meal
    @meal.build_cost
    @dupes = []
  end

  def do_finalize
    @meal = Meal.find(params[:id])
    authorize @meal, :finalize?

    # We assign finalized here so that the meal/signup validations don't complain about no spots left.
    @meal.assign_attributes(finalize_params.merge(status: "finalized"))

    if (@dupes = @meal.duplicate_signups).any?
      flash.now[:error] = "There are duplicate signups. "\
        "Please correct by adding numbers for each diner type."
      render(:finalize)
    elsif @meal.valid?
      Meal.transaction do
        Meals::Finalizer.new(@meal).finalize!
      end
      flash[:success] = "Meal finalized successfully"
      redirect_to(meals_path(finalizable: 1))
    else
      set_validation_error_notice
      render(:finalize)
    end
  end

  def reopen
    @meal = Meal.find(params[:id])
    authorize @meal
    @meal.reopen!
    flash[:success] = "Meal reopened successfully."
    redirect_to(meals_path)
  end

  def summary
    @meal = Meal.find(params[:id])
    authorize @meal
    load_signups
    @cost_calculator = MealCostCalculator.build(@meal)
    if @meal.open? && current_user == @meal.head_cook
      flash.now[:alert] = "Note: This meal is not yet closed and people can still sign up for it. "\
        "You should close the meal using the link below before printing this summary."
    end
  end

  def destroy
    @meal = Meal.find(params[:id])
    authorize @meal
    if @meal.destroy
      flash[:success] = "Meal deleted successfully."
    else
      flash[:error] = "Meal deletion failed."
    end
    redirect_to(meals_path)
  end

  protected

  def default_url_options
    {mode: params[:mode]}
  end

  private

  def init_meal
    @meal = Meal.new_with_defaults(current_user)
  end

  def load_meals
    @meals = policy_scope(Meal)
    if lens[:time] == "finalizable"
      @meals = @meals.finalizable.where(host_community_id: current_user.community_id).oldest_first
    elsif lens[:time] == "past"
      @meals = @meals.past.newest_first
    elsif lens[:time] == "all"
      @meals = @meals.oldest_first
    else
      @meals = @meals.future.oldest_first
    end
    @meals = @meals.includes(:signups)
    if params[:search]
      @meals = @meals.joins(:head_cook).
        where("title ILIKE ? OR users.first_name ILIKE ? OR users.last_name ILIKE ?",
          "%#{params[:search]}%", "%#{params[:search]}%", "%#{params[:search]}%")
    end

    @meals = @meals.worked_by(lens[:user]) if lens[:user].present?
    @meals = @meals.hosted_by(Community.find_by_abbrv(lens[:community])) if lens[:community].present?
    @meals = @meals.page(params[:page])
  end

  def load_signups
    @signups = @meal.signups.host_community_first(@meal.host_community).sorted
  end

  def prep_form_vars
    @meal.ensure_assignments
    load_communities
    @resource_options = Reservation::Resource.meal_hostable.by_full_name
  end

  def finalize_params
    params.require(:meal).permit(
      signups_attributes: [:id, :household_id, :_destroy] + Signup::SIGNUP_TYPES,
      cost_attributes: [:ingredient_cost, :pantry_cost, :payment_method]
    )
  end

  def create_worker_change_notifier
    @meal = Meal.find(params[:id])
    if !policy(@meal).administer?
      @worker_change_notifier = Meals::WorkerChangeNotifier.new(current_user, @meal)
    end
  end
end
