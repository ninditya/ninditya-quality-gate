# frozen_string_literal: true

module AuthHelpers
  # A signed assessor token for the given organization, as the login endpoint
  # would issue it.
  def token_for(org, role: 'admin', user_id: 1)
    JsonWebToken.encode({ user_id: user_id, role: role, scheme: org.scheme })
  end

  def auth_headers(org, **opts)
    { 'Authorization' => "Bearer #{token_for(org, **opts)}" }
  end
end
