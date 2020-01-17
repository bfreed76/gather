# frozen_string_literal: true

module Groups
  # Maintains correct group memberships when other models change.
  class MembershipMaintainer
    include Singleton

    def user_committed(user)
      return unless user.saved_change_to_deactivated_at? && user.inactive?
      user.group_memberships.destroy_all
    end

    def destroy_groups_affiliation_successful(affiliation)
      Membership.joins(:user).merge(User.in_community(affiliation.community_id))
        .where(group_id: affiliation.group_id).destroy_all
    end
  end
end
