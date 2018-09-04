# Models a set of Rules governing a single reservation.
# Represents the unification of one or more protocols.
module Reservations
  class RuleSet
    include ActiveModel::SerializerSupport

    attr_accessor :reservation, :rules

    # Finds all matching protocols and unions them into one.
    # Raises an error if any two protocols have non-nil values for the same attrib.
    def self.build_for(reservation)
      protocols = Protocol.matching(reservation.resource, reservation.kind)

      rules = {}.tap do |result|
        Rule::NAMES.each do |n|
          protocols_with_attr = protocols.select{ |p| p[n].present? }

          if protocols_with_attr.size > 1
            raise ProtocolDuplicateDefinitionError.new(attrib: n, protocols: protocols_with_attr)
          elsif protocols_with_attr.size == 0
            next
          end

          protocol = protocols_with_attr.first
          result[n] = Rule.new(name: n, value: protocol[n], protocol: protocol)
        end
      end

      new(reservation: reservation, rules: rules)
    end

    def initialize(reservation:, rules:)
      self.reservation = reservation
      self.rules = rules
    end

    def [](key)
      rules[key]
    end

    def access_level
      if (oc = rules[:other_communities]) && oc.community != reservation.reserver_community
        oc.value
      else
        "ok"
      end
    end

    def fixed_start_time?
      rules[:fixed_start_time].present?
    end

    def fixed_end_time?
      rules[:fixed_end_time].present?
    end

    def requires_kind?
      rules[:requires_kind].present?
    end

    def fixed_start_time
      rules[:fixed_start_time].try(:value)
    end

    def fixed_end_time
      rules[:fixed_end_time].try(:value)
    end

    def pre_notice?
      rules[:pre_notice].present?
    end

    def pre_notice
      rules[:pre_notice].try(:value)
    end

    def to_s
      rules.values.map(&:to_s).join("\n")
    end
  end
end
