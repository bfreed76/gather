class HouseholdPolicy < ApplicationPolicy
  alias_method :household, :record

  class Scope < Scope
    def resolve
      if active_super_admin?
        scope
      elsif active?
        scope.in_cluster(user.cluster)
      else
        scope.none
      end
    end

    def administerable
      if active_super_admin?
        scope
      elsif active_cluster_admin?
        scope.in_cluster(user.cluster)
      elsif active_admin?
        scope.where(community_id: user.community_id)
      else
        scope.none
      end
    end
  end

  def index?
    active_in_cluster? || active_super_admin?
  end

  def show?
    active_in_cluster? || active_admin?
  end

  def show_personal_info?
    active_in_community? || active_admin?
  end

  def create?
    active_admin?
  end

  def update?
    active_admin? || household == user.household
  end

  def activate?
    household.inactive? && active_admin?
  end

  def deactivate?
    household.active? && active_admin?
  end

  def administer?
    active_admin?
  end

  def change_community?
    active_cluster_admin?
  end

  # TODO: This should probably move into the CommunityPolicy as a scope method similar to
  # administerable above.
  def allowed_community_changes
    if active_super_admin?
      Community.all
    elsif active_cluster_admin?
      Community.where(cluster: user.cluster)
    elsif active_admin?
      Community.where(id: user.community_id)
    else
      Community.none
    end
  end

  # TODO: This should probably move too.
  # Checks that the community_id param in the given hash is an allowable change.
  # If it is not, sets the param to nil.
  def ensure_allowed_community_id(params)
    unless allowed_community_changes.map(&:id).include?(params[:community_id].to_i)
      # Important to delete instead of set to nil, as setting to nil
      # will set the household to nil and the form won't save.
      params.delete(:community_id)
    end
  end

  def accounts?
    active_admin_or?(:biller) || household == user.household
  end

  def destroy?
    active_admin? && !record.any_users? && !record.any_assignments? && !record.any_signups? && !record.any_accounts?
  end

  def permitted_attributes
    permitted = [:name, :garage_nums, :keyholders]
    permitted.concat([:unit_num, :old_id, :old_name]) if administer?
    permitted << :community_id if administer?
    permitted << {vehicles_attributes: [:id, :make, :model, :color, :plate, :_destroy]}
    permitted << {emergency_contacts_attributes: [:id, :name, :relationship, :main_phone, :alt_phone,
      :email, :location, :_destroy]}
    permitted << {pets_attributes: [:id, :name, :species, :color, :vet, :caregivers,
      :health_issues, :_destroy]}
    permitted
  end
end
