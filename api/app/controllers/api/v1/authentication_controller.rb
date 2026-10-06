# frozen_string_literal: true

module Api
  module V1
    class AuthenticationController < ApiController
      skip_before_action :require_tenant!

      # POST /api/v1/auth/login
      def authenticate
        user = User.find_by(email: params[:email].to_s.downcase)

        return json_error('Invalid email or password', :unauthorized) unless user&.authenticate(params[:password])

        return json_error('Invalid email or password', :unauthorized) unless user.role == 'admin'

        # The tenant comes from the account, never from the request. It used to
        # be taken from an X-Tenant-Scheme header (or "the first organization"),
        # which let any assessor mint a token for any tenant.
        organization = user.organization
        return json_error('This account is not linked to an organization', :forbidden) unless organization

        token = JsonWebToken.encode({ user_id: user.id, role: user.role, scheme: organization.scheme })

        json_response({
          token:,
          user:         { id: user.id, email: user.email, role: user.role },
          organization: { id: organization.id, name: organization.name }
        })
      end
    end
  end
end
