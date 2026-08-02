# Test support for apps using verify_human. Requires WebMock.
#
#   require "verify_human/test_helpers"
#   include HumanVerification::TestHelpers
module HumanVerification
  module TestHelpers
    # Swaps in credentials that answer turnstile keys while delegating every
    # other lookup to the real credentials.
    def with_human_verification_configured(&block)
      credentials = Class.new(SimpleDelegator) do
        def dig(*keys)
          case keys
          in [:turnstile, :secret_key] then "test-secret"
          in [:turnstile, :site_key] then "test-site-key"
          in [:turnstile, :invisible_secret_key] then "test-invisible-secret"
          in [:turnstile, :invisible_site_key] then "test-invisible-site-key"
          else super
          end
        end

        # EncryptedConfiguration claims to respond to everything, which makes
        # Minitest's stub treat this object as a callable and replace it with
        # the result of #call. Deny :call so stub returns the object itself.
        def respond_to?(name, include_private = false)
          return false if name == :call
          super
        end
      end.new(Rails.application.credentials)

      Rails.application.stub(:credentials, credentials, &block)
    end

    def stub_human_verification(success:, action: nil)
      body = {success: success}
      body[:action] = action if action
      stub_request(:post, HumanVerification::VERIFY_URL)
        .to_return(body: body.to_json, headers: {"Content-Type" => "application/json"})
    end

    def stub_human_verification_outage
      stub_request(:post, HumanVerification::VERIFY_URL).to_timeout
    end
  end
end
