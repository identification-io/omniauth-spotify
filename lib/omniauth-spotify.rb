require 'omniauth/strategies/oauth2'
require 'date'

module OmniAuth
  module Strategies
    class Spotify < OmniAuth::Strategies::OAuth2
      # Give your strategy a name.
      option :name, 'spotify'

      FORCE_APPROVAL_KEY = 'ommiauth_spotify_force_approval?'.freeze

      # This is where you pass the options you would pass when
      # initializing your consumer from the OAuth gem.
      option :client_options, {
        site:          'https://api.spotify.com/v1',
        authorize_url: 'https://accounts.spotify.com/authorize',
        token_url:     'https://accounts.spotify.com/api/token',
      }

      option :authorize_options, [:scope, :show_dialog]

      # These are called after authentication has succeeded. If
      # possible, you should try to set the UID without making
      # additional calls (if the user id is returned with the token
      # or as a URI parameter). This may not be possible with all
      # providers.
      uid{ raw_info['id'] }

      info do
        {
          # Unless the 'user-read-private' scope is included, the birthdate, country, image, and product fields may be nil,
          # and the name field will be set to the username/nickname instead of the display name.
          # The email field will be nil if the 'user-read-email' scope isn't included.
          #
          name:     raw_info['display_name'] || raw_info['id'],
          nickname: raw_info['id'],
          email:    raw_info['email'],
          urls:     raw_info['external_urls'],
          image:    image_url,
          location: raw_info['country'],

          # non-standard

          birthdate:      raw_info['birthdate'] && Date.parse(raw_info['birthdate']),
          country_code:   raw_info['country'],
          product:        raw_info['product'],
          follower_count: raw_info['followers']['total']
        }
      end

      extra do
        {
          raw_info: raw_info
        }
      end

      def image_url
        image = Array(raw_info['images']).first
        image['url'] if image
      end

      def raw_info
        @raw_info ||= access_token.get('me').parsed
      end

      def authorize_params
        super.tap do |params|
          if session.delete(FORCE_APPROVAL_KEY) || session.fetch(:flash, {}).fetch('flashes', {})[FORCE_APPROVAL_KEY]
            params[:show_dialog] = true
          end
        end
      end

      def request_phase
        %i[show_dialog].each do |key|
          options[:authorize_params][key] = request.params[key] if request.params[key]
        end

        super
      end

      def callback_url
        return '' if @authorization_code_from_signed_request_in_cookie

        # Fixes regression in omniauth-oauth2 v1.4.0
        # See: https://github.com/intridea/omniauth-oauth2/commit/85fdbe117c2a4400d001a6368cc359d88f40abc7
        options[:callback_url] || (full_host + script_name + callback_path)
      end
    end
  end
end
