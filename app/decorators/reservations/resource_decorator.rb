# frozen_string_literal: true

module Calendars
  class CalendarDecorator < ApplicationDecorator
    delegate_all

    def name_with_prefix
      "#{cmty_prefix_no_colon}#{name}"
    end

    def name_with_inactive
      "#{name}#{active? ? '' : ' (Inactive)'}"
    end

    def abbrv_with_prefix
      "#{cmty_prefix_no_colon}#{abbrv}"
    end

    def tr_classes
      active? ? "" : "inactive"
    end

    def photo_variant(format)
      return "missing/calendars/calendars/#{format}.png" unless photo.attached? && photo.variable?
      case format
      when :thumb then photo.variant(resize_to_fill: [220, 165])
      else raise "Unknown photo format #{format}"
      end
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :deactivate, icon: "times-circle", method: :put, confirm: {name: name},
                                            path: h.deactivate_calendar_path(object)),
        ActionLink.new(object, :destroy, icon: "trash", method: :delete, confirm: {name: name},
                                         path: h.calendar_path(object))
      )
    end
  end
end
