module HumanVerification
  extend ActiveSupport::Concern

  VERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  class_methods do
    # Declare after any rate_limit so the cheap local check runs first.
    # Guards :create by default -- the public form submissions bots abuse.
    # Pass only:/except: to protect other actions (their forms need a widget).
    def verify_human(name = nil, **options)
      options[:only] = :create unless options.key?(:only) || options.key?(:except)
      before_action(**options) { verify_turnstile(name) }
    end
  end

  private

  def verify_turnstile(expected_name = nil)
    return unless human_verification_enabled?
    return if turnstile_token_valid?(expected_name)

    human_verification_failed
  end

  # Override in controllers that need a custom failure response (e.g. forms
  # inside a turbo frame, where a redirect yields "Content missing" and
  # discards the user's input).
  def human_verification_failed
    redirect_back fallback_location: root_path,
      alert: "We couldn't verify you're human. Please try again."
  end

  # Both keys or nothing: enforcing with only a secret_key would reject every
  # submission, because human_verification_tag renders no widget without a site_key.
  # (HumanVerificationHelper duplicates this check for view code.)
  def human_verification_enabled?
    %i[site_key secret_key].all? { |key| Rails.application.credentials.dig(:turnstile, key).present? }
  end

  # Tokens are widget-specific: a page may run the invisible-mode widget while
  # other forms run the managed one. The form says which one minted the token
  # (spoofing the param just fails verification against the wrong secret).
  def turnstile_secret_key
    key = (params[:cf_turnstile_widget] == "invisible") ? :invisible_secret_key : :secret_key
    Rails.application.credentials.dig(:turnstile, key)
  end

  def turnstile_token_valid?(expected_name)
    return false if params[:cf_turnstile_response].blank?

    response = Faraday.post(VERIFY_URL,
      secret: turnstile_secret_key,
      response: params[:cf_turnstile_response],
      remoteip: request.remote_ip) do |req|
      # Well under rack-timeout's 20s budget, so a slow Cloudflare fails open
      # via the rescue below instead of 500ing the request.
      req.options.open_timeout = 2
      req.options.timeout = 3
    end

    # Cloudflare calls the per-widget name "action" in its API. Its testing
    # keys (development) answer without one, flagged in the metadata.
    data = JSON.parse(response.body)
    data["success"] && (expected_name.nil? || data["action"] == expected_name || data.dig("metadata", "result_with_testing_key") == true)
  rescue Faraday::Error, JSON::ParserError => error
    Rails.error.report(error)
    true # Fail open: never lock users out because Cloudflare is unreachable
  end
end
