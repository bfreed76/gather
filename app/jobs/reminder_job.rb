# frozen_string_literal: true

class ReminderJob < ApplicationJob
  def max_attempts
    1
  end

  protected

  def each_community_at_correct_hour
    each_community do |community|
      yield(community) if correct_hour?
    end
  end

  def correct_hour?
    Rails.env.development? || Time.current.hour == Settings.reminders.time_of_day
  end
end
