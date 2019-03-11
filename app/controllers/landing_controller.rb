# frozen_string_literal: true

# Controls landing, ping, privacy policy, and other assorted pages.
class LandingController < ApplicationController
  skip_before_action :authenticate_user!
  skip_after_action :verify_authorized
  skip_after_action :verify_policy_scoped

  def index
    @invite_token = params[:token]
    render(layout: false)
  end

  # Used by uptime checker
  def ping
    @status = SystemStatus.new
    render(layout: nil, formats: :text, status: @status.ok? ? 200 : 503)
  end

  def signed_out
    if user_signed_in?
      redirect_to(root_path)
    else
      flash.delete(:notice)
      render(layout: false)
    end
  end

  def public_static
    render_not_found unless %w[privacy-policy markdown].include?(params[:page])
    render(params[:page].tr("-", "_"))
  end
end
