require 'minitest/autorun'
require 'json'
require 'ostruct'

module EmailHelper; end
module DeviseOverrides; end
module DeviseTokenAuth
  class OmniauthCallbacksController
    attr_accessor :request, :session, :params

    def redirect_callbacks
      session['dta.omniauth.auth'] = request.env['omniauth.auth'].except('extra')
      session['dta.omniauth.params'] = request.env['omniauth.params']
      :redirected
    end

    def auth_hash
      session.delete('dta.omniauth.auth')
    end
  end
end

class Class
  def prepend_mod_with(_name); end
end
require '/src/app/controllers/devise_overrides/omniauth_callbacks_controller'

class OidcCookieHandoffTest < Minitest::Test
  def build_controller(provider:, payload:)
    controller = DeviseOverrides::OmniauthCallbacksController.new
    controller.params = { provider: provider }
    controller.request = OpenStruct.new(env: {
      'omniauth.auth' => payload,
      'omniauth.params' => { 'resource_class' => 'User' }
    })
    controller.session = {}
    controller
  end

  def test_oidc_verified_identity_is_retained_without_oversized_tokens_or_profile
    payload = {
      'provider' => 'openid_connect', 'uid' => 'akadmin',
      'info' => { 'email' => 'a.cali@warancloud.com', 'name' => 'A Cali',
                  'email_verified' => true, 'image' => 'https://example.invalid/photo' },
      'credentials' => { 'token' => 't' * 7000, 'refresh_token' => 'r' * 7000 },
      'extra' => { 'raw_info' => 'x' * 7000 }
    }
    controller = build_controller(provider: 'openid_connect', payload: payload)
    assert_equal :redirected, controller.redirect_callbacks
    assert_operator JSON.generate(controller.session).bytesize, :<, 2048
    identity = controller.auth_hash
    assert_equal 'a.cali@warancloud.com', identity.dig('info', 'email')
    assert_equal 'A Cali', identity.dig('info', 'name')
    assert_equal true, identity.dig('info', 'email_verified')
    refute identity.key?('credentials')
    refute identity.dig('info', 'image')
  end

  def test_google_handoff_remains_unchanged
    payload = { 'provider' => 'google_oauth2', 'info' => { 'email' => 'g@example.com' },
                'credentials' => { 'token' => 'google-token' } }
    controller = build_controller(provider: 'google_oauth2', payload: payload)
    assert_equal :redirected, controller.redirect_callbacks
    assert_equal 'google-token', controller.auth_hash.dig('credentials', 'token')
  end
end
