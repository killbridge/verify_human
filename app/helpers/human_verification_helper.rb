module HumanVerificationHelper
  # Renders nothing when no site key is configured (development/test).
  # With auto_submit: true the surrounding form is submitted as soon as
  # Cloudflare issues a token.
  # With invisible: true, an invisible-mode widget runs instead: it never
  # shows UI, and when it cannot pass silently the form simply posts without
  # a token and the interstitial takes over. The paired hidden field tells
  # the server which widget's secret to verify against.
  def human_verification_tag(name = nil, auto_submit: false, invisible: false, **options)
    return unless human_verification_enabled?

    widget = tag.div(**options, data: {
      controller: "turnstile",
      turnstile_site_key_value: Rails.application.credentials.dig(:turnstile, invisible ? :invisible_site_key : :site_key),
      turnstile_action_value: name,
      turnstile_auto_submit_value: auto_submit
    })
    invisible ? widget + hidden_field_tag(:cf_turnstile_widget, "invisible") : widget
  end

  # Both keys or nothing, matching HumanVerification#human_verification_enabled?
  # (intentionally the same name): rendering a widget without a secret_key
  # would collect tokens the server never checks, and enforcing without a
  # site_key would reject every submission.
  def human_verification_enabled?
    %i[site_key secret_key].all? { |key| Rails.application.credentials.dig(:turnstile, key).present? }
  end
end
