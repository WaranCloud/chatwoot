# OmniAuth configuration
# Sets the full host URL for callbacks and proper redirect handling
OmniAuth.config.full_host = ENV.fetch('FRONTEND_URL', 'http://localhost:3000')

# Caawiye fork: permit the GET request phase. devise_token_auth answers the
# authorize POST with a 307 to /omniauth/:provider, which the browser follows as
# GET; with OmniAuth 2's default (POST only) that handoff 404s.
OmniAuth.config.allowed_request_methods = %i[get post]

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV.fetch('GOOGLE_OAUTH_CLIENT_ID', nil), ENV.fetch('GOOGLE_OAUTH_CLIENT_SECRET', nil), {
    provider_ignores_state: true
  }

  # Caawiye fork: generic OIDC provider, registered only when configured.
  # Works with Authentik/Keycloak/Okta/Entra via standard OIDC discovery.
  if ENV.fetch('OIDC_ISSUER', nil).present?
    provider :openid_connect,
             name: :openid_connect,
             issuer: ENV.fetch('OIDC_ISSUER'),
             discovery: true,
             scope: %i[openid email profile],
             response_type: :code,
             client_options: {
               identifier: ENV.fetch('OIDC_CLIENT_ID'),
               secret: ENV.fetch('OIDC_CLIENT_SECRET'),
               redirect_uri: ENV.fetch(
                 'OIDC_REDIRECT_URI',
                 "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/omniauth/openid_connect/callback"
               )
             }
  end
end
