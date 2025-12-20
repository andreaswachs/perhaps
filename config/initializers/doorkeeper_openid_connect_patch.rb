# frozen_string_literal: true

# Monkey-patch to fix DoubleRenderError in doorkeeper-openid_connect
# when prompt=consent is passed in the authorization request.
#
# The gem's handle_oidc_prompt_param! method calls `render :new` when
# prompt=consent is specified, but it doesn't clear any existing response
# body first, causing a DoubleRenderError.
#
# This patch uses the same approach the gem uses for error handling
# (in handle_oidc_error!): clear the response body before rendering.

Rails.application.config.after_initialize do
  Doorkeeper::OpenidConnect::Helpers::Controller.module_eval do
    private

      def handle_oidc_prompt_param!(owner)
        prompt_values ||= params[:prompt].to_s.split(/ +/).uniq

        priority = [ "none", "consent", "login", "select_account" ]
        prompt_values.sort_by! do |prompt|
          priority.find_index(prompt).to_i
        end

        prompt_values.each do |prompt|
          case prompt
          when "none"
            raise Doorkeeper::OpenidConnect::Errors::InvalidRequest if (prompt_values - [ "none" ]).any?
            raise Doorkeeper::OpenidConnect::Errors::LoginRequired unless owner
            raise Doorkeeper::OpenidConnect::Errors::ConsentRequired if oidc_consent_required?
          when "login"
            reauthenticate_oidc_resource_owner(owner) if owner
          when "consent"
            if owner
              # Clear any existing response body to avoid DoubleRenderError
              # This mirrors what handle_oidc_error! does
              self.response_body = nil
              @_response_body = nil
              render :new
            end
          when "select_account"
            select_account_for_oidc_resource_owner(owner)
          when "create"
            # NOTE: not supported, but not raise error.
          else
            raise Doorkeeper::OpenidConnect::Errors::InvalidRequest
          end
        end
      end
  end
end
