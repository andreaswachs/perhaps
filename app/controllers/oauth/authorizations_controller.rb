# frozen_string_literal: true

# Custom OAuth Authorizations Controller
# Fixes a DoubleRenderError in doorkeeper-openid_connect when prompt=consent is passed.
# The gem's handle_oidc_prompt_param! method calls `render :new` in a before_action,
# but doesn't prevent the main action from also rendering.
module Oauth
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    # Override the new action to check if a render has already been performed
    # (e.g., by handle_oidc_prompt_param! for prompt=consent)
    def new
      # If the OIDC prompt handling already rendered, don't render again
      return if performed?

      super
    end

    # Override create to also check for prior renders
    def create
      return if performed?

      super
    end
  end
end
