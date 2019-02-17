# frozen_string_literal: true

module Work
  # Controls job signup pages.
  class ShiftsController < WorkController
    before_action -> { nav_context(:work, :signups) }
    decorates_assigned :shifts, :shift, :choosee, :meal
    helper_method :sample_shift, :synopsis, :shift_policy, :cache_key

    def index
      authorize(sample_shift, :index_wrapper?)
      prepare_lenses_and_set_contextual_vars

      # Need to do this early because it could affect policies and cache key.
      @period&.auto_open_if_appropriate

      @shifts = policy_scope(Shift)
      @shifts = @shifts.none unless policy(sample_shift).index?

      if @period.nil?
        lenses.hide!
      else
        scope_shifts
        @autorefresh = !params[:norefresh] && (@period.pre_open? || @period.open?)

        if request.xhr?
          render_shifts_and_pagination_json
        elsif @period.archived?
          flash.now[:notice] = t("work.phase_notices.shifts.archived")
        end
      end
    end

    def show
      @shift = Shift.find(params[:id])
      authorize @shift
      @meal = @shift.meal
    end

    # Called from AJAX on signup link click.
    # If there are no slots left, shift card will include error message.
    def signup
      prepare_lenses_and_set_contextual_vars
      @shift = Shift.find(params[:id])

      begin
        authorize_and_do_signup_or_raise_error
        raise_stubbed_error_in_test_mode
      rescue RoundLimitExceededError
        @error = t("work/shift.round_limit_exceeded")
      rescue SlotsExceededError
        @error = t("work/shift.slots_exceeded")
      rescue AlreadySignedUpError
        @error = t("work/shift.already_signed_up")
      end

      if request.xhr?
        # Synopsis was already computed once for authorization. Force recalculation after change.
        @synopsis = nil
        render_shift_and_synopsis_json
      else
        if @error
          flash[:error] = @error
        else
          flash[:success] = "You signed up successfully. Hooray!"
        end
        redirect_to(work_shifts_path)
      end
    end

    def unsignup
      prepare_lenses_and_set_contextual_vars
      @shift = Shift.find(params[:id])
      authorize @shift

      if request.xhr?
        begin
          @shift.unsignup_user(@choosee)
        rescue NotSignedUpError
          @error = t("work/shift.not_signed_up")
        end
        render_shift_and_synopsis_json
      else
        begin
          @shift.unsignup_user(@choosee)
          flash[:success] = "Your signup was removed successfully."
        rescue NotSignedUpError
          flash[:error] = t("work/shift.not_signed_up")
        end
        redirect_to(work_shifts_path)
      end
    end

    protected

    def klass
      Job
    end

    private

    def prepare_lenses_and_set_contextual_vars
      names = params[:action] == "index" ? %i[search work/shift] : []
      names << :"work/period" << {"work/choosee": {chooser: current_user}}
      prepare_lenses(*names)
      @period = lenses[:period].object
      @choosee = lenses[:choosee].choosee
      return if @choosee == current_user
      flash.now[:notice] = t("work.choosing_as", name: choosee.full_name)
    end

    def render_shift_and_synopsis_json
      render json: {
        shift: render_to_string(partial: "shift", locals: {shift: shift}),
        synopsis: render_to_string(partial: "synopsis")
      }
    end

    # We render shifts and pagination separately so we don't have to render the "choose as" dropdown
    # every refresh (saving a few database hits).
    def render_shifts_and_pagination_json
      render json: {
        shifts: render_to_string(partial: "shifts"),
        pagination: render_to_string(partial: "pagination")
      }
    end

    def sample_shift
      period = @period || sample_period
      Shift.new(job: Job.new(period: period))
    end

    def scope_shifts
      @shifts = @shifts
        .in_community(current_community)
        .in_period(@period)
        .includes(job: {period: :community}, assignments: :user)
        .by_job_title
        .by_date
        .page(params[:page])
        .per(48) # multiple of 2, 3, & 4
      apply_shift_lens
      apply_search_lens
    end

    def authorize_and_do_signup_or_raise_error
      # Since we have a custom built policy object, we need to do our own custom authorization.
      # If authorization fails due to round limit being exceeded, raise a special error.
      skip_authorization
      policy = shift_policy(@shift)
      if policy.signup?
        @shift.signup_user(@choosee)
      elsif policy.round_limit_exceeded?
        raise RoundLimitExceededError
      else
        # At this point we don't know what cause the auth fail, so force a failure.
        authorize(@shift, :fail?)
      end
    end

    def raise_stubbed_error_in_test_mode
      raise ENV["STUB_SIGNUP_ERROR"].constantize if Rails.env.test? && ENV["STUB_SIGNUP_ERROR"]
    end

    def apply_shift_lens
      @shifts =
        case lenses[:shift].value
        when "open" then @shifts.open
        when "me" then @shifts.with_user(@choosee)
        when "myhh" then @shifts.with_user(@choosee.household.users)
        when "notpre" then @shifts.with_non_preassigned_or_empty_slots
        else lenses[:shift].requester_id ? @shifts.from_requester(lenses[:shift].requester_id) : @shifts
        end
    end

    def apply_search_lens
      return if lenses[:search].blank?
      search = Work::Shift.search(
        query: {
          multi_match: {
            fields: Work::Shift.indexed_fields,
            query: lenses[:search].value,
            type: :cross_fields,
            operator: :and
          }
        },
        # We set size to 10k because we don't need to worry about restricting the result set here.
        # It's restricted for us by the other scoping stuff.
        # TODO: This is a big problem because it doesn't scale. We need to change the above lens application
        # stuff to use the search fields, at least for period and community
        size: 10_000
      )
      @shifts = @shifts.merge(search.records.records)
    end

    # Custom-builds a ShiftPolicy object with the given shift, including the synopsis if appropriate.
    def shift_policy(shift)
      ShiftPolicy.new(@choosee, shift, synopsis: shift.period.staggered? ? synopsis.object : nil)
    end

    def synopsis
      raise "period must be set to build synopsis" unless @period
      # Draper inferral is not working here for some reason.
      @synopsis ||= SynopsisDecorator.new(Synopsis.new(period: @period, user: @choosee))
    end

    # Cache key for the index page.
    def cache_key
      chunks = [@choosee.id, @period.cache_key, @shifts.cache_key, lenses.cache_key, params[:page] || 1]

      # Need to include current minutes/5 if staggered because the round limit calculations
      # may change things just with the passage of time. We know things only change this way at 5-minute
      # increments though.
      chunks << (Time.current.seconds_since_midnight / 300).floor if @period.staggered?

      chunks.join("|")
    end
  end
end
