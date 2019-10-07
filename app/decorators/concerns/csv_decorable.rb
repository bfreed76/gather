# frozen_string_literal: true

module CsvDecorable
  extend ActiveSupport::Concern

  private

  def l(date_or_time)
    return nil if date_or_time.nil?
    I18n.l(date_or_time, format: :csv_full)
  end

  def bool(val)
    I18n.t("common.#{val ? 'true' : 'false'}")
  end
end
