# frozen_string_literal: true

# Implements a user select dropdown either as a select2 (hence why we inherit from AssocSelect2)
# or as a simple dropdown (which we achieve by not setting up all the select2 tag attributes)
class UserSelectInput < SimpleForm::Inputs::CollectionSelectInput
  include AssocSelect2able

  def input(wrapper_options)
    # We can't use a plain user select for the specific_community_adults context if multi community
    # it's dependent on a selection in the form so AJAX is required.
    if current_community.settings.people.plain_user_selects &&
        !(current_cluster.multi_community? && options["context"] == "specific_community_adults")
      setup_plain_select
    else
      setup_select2
    end
    super(wrapper_options)
  end

  private

  delegate :current_community, :current_cluster, to: :template

  def setup_plain_select
    users = UserPolicy::Scope.new(template.current_user, User).resolve.by_name
    users = case options[:context]
            when "current_community_adults", "specific_community_adults"
              users.active.in_community(current_community).adults
            when "guardians"
              users.active.in_community(current_community).can_be_guardian
            when "current_cluster_adults"
              users.active.adults
            when "current_community_all"
              users.active.in_community(current_community)
            when "current_community_inactive"
              users.inactive.in_community(current_community)
            else
              raise "invalid select2 context"
            end
    options[:collection] = users
    options[:include_blank] = options[:allow_clear] == true
    options[:prompt] = options[:allow_clear] == true ? false : "Select User ..."
  end
end
