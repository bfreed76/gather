module Work
  class Job < ApplicationRecord
    TIMES_OPTIONS = %i[date_time date_only full_period].freeze
    SLOT_TYPE_OPTIONS = %i[fixed full_single full_multiple].freeze
    WITH_PREASSIGN_SQL = "EXISTS (SELECT ws.id FROM work_shifts ws
      INNER JOIN work_assignments wa ON wa.shift_id = ws.id
      WHERE ws.job_id = work_jobs.id AND wa.preassigned = 't')".freeze

    acts_as_tenant :cluster

    belongs_to :period, class_name: "Work::Period", inverse_of: :jobs
    belongs_to :requester, class_name: "People::Group"
    has_many :shifts, -> { by_time }, class_name: "Work::Shift", inverse_of: :job, dependent: :destroy
    has_many :reminders, class_name: "Work::Reminder", inverse_of: :job, dependent: :destroy

    scope :for_community, ->(c) { joins(:period).where("work_periods.community_id": c.id) }
    scope :by_title, -> { order("LOWER(title)") }
    scope :in_period, ->(p) { where(period: p) }
    scope :from_requester, ->(r) { where(requester: r) }
    scope :fixed_slot, -> { where(slot_type: "fixed") }
    scope :full_community, -> { where(slot_type: %w[full_single full_multiple]) }
    scope :with_preassignments, -> { where(WITH_PREASSIGN_SQL) }
    scope :with_no_preassignments, -> { where("NOT #{WITH_PREASSIGN_SQL}") }

    normalize_attributes :title, :description

    before_validation :normalize
    after_update { ShiftIndexUpdater.new(self).update }

    # Need to use after_commit here because after_update doesn't run on touch.
    after_commit { reminders.each(&:create_or_update_deliveries) }

    validates :period, presence: true
    validates :title, presence: true, length: {maximum: 128}, uniqueness: {scope: :period_id}
    validates :hours, presence: true, numericality: {greater_than: 0}
    validates :time_type, presence: true
    validates :slot_type, presence: true
    validates :hours_per_shift, presence: true, if: :date_only_full_community_multiple_slot?
    validates :description, presence: true
    validate :valid_shift_count
    validate :no_duplicate_start_end_times
    validate :shifts_same_length_for_date_time_full_multiple
    validate :hours_per_shift_evenly_divides_hours

    accepts_nested_attributes_for :shifts, reject_if: :all_blank, allow_destroy: true
    accepts_nested_attributes_for :reminders, reject_if: :all_blank, allow_destroy: true

    delegate :community, to: :period
    delegate :starts_on, :ends_on, :name, :draft?, :open?, :pending?, :published?, :archived?,
      to: :period, prefix: true

    def full_period?
      time_type == "full_period"
    end

    def date_only?
      time_type == "date_only"
    end

    def date_time?
      time_type == "date_time"
    end

    def full_community?
      slot_type != "fixed"
    end

    def fixed_slot?
      slot_type == "fixed"
    end

    def full_community_single_slot?
      slot_type == "full_single"
    end

    def full_community_multiple_slot?
      slot_type == "full_multiple"
    end

    def date_only_full_community_multiple_slot?
      date_only? && full_community_multiple_slot?
    end

    def preassignments?
      shifts.any?(&:preassignments?)
    end

    def total_slots
      shifts.sum(&:slots)
    end

    # Should be used with eager loading.
    def assignments
      shifts.flat_map(&:assignments)
    end

    private

    def normalize
      self.hours_per_shift = nil unless date_only_full_community_multiple_slot?
    end

    def shift_count
      @shift_count ||= shifts.reject(&:marked_for_destruction?).size
    end

    def valid_shift_count
      if shift_count.zero?
        errors.add(:shifts, :no_shifts)
      elsif shift_count > 1 && full_community_single_slot?
        errors.add(:shifts, :more_than_one_shift_for_full_single)
      elsif shift_count > 1 && full_period?
        errors.add(:shifts, :more_than_one_shift_for_full_period)
      end
    end

    def no_duplicate_start_end_times
      return unless shifts.map { |s| [s.starts_at, s.ends_at] }.uniq.size < shifts.size
      errors.add(:shifts, :duplicate_start_end_times)
    end

    def shifts_same_length_for_date_time_full_multiple
      return unless date_time? && full_community_multiple_slot? && shifts.map(&:elapsed_time).uniq.size != 1
      errors.add(:shifts, :different_length_shifts)
    end

    def hours_per_shift_evenly_divides_hours
      return unless hours_per_shift.present? && hours % hours_per_shift != 0
      errors.add(:hours_per_shift, :uneven_divisor, hours: hours)
    end
  end
end
