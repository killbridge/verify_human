# verify_human

Human verification for Rails forms. Cloudflare Turnstile under the hood; provider-agnostic API on the surface.

This is an opinionated gem: it does human verification the way I like it in my own Rails apps. It's shared in case that way suits you too, not as a general-purpose library that tries to fit every setup.

## Installation

```ruby
gem "verify_human", github: "killbridge/verify_human"
```

## Usage

```ruby
# ApplicationController (or a specific controller)
include HumanVerification

# Any controller with a form bots abuse. Guards :create by default;
# declare AFTER rate_limit so the cheap local check runs first.
rate_limit to: 5, within: 15.minutes, only: :create
verify_human "sign_in"
```

```erb
<%# In the form. Invisible for ~98% of visitors (interaction-only Managed
    widget); shows a one-click checkbox only when Cloudflare requires it. %>
<%= human_verification_tag "sign_in" %>

<%# Submit the surrounding form as soon as a token is issued: %>
<%= human_verification_tag "apply", auto_submit: true %>

<%# Never show UI at all (separate invisible-mode widget; visitors who can't
    pass silently post tokenless -- pair with a retry/interstitial flow): %>
<%= human_verification_tag "apply", invisible: true %>
```

Override the failure response per controller (default: `redirect_back` with an alert):

```ruby
def human_verification_failed
  flash.now[:alert] = "We couldn't verify you're human. Please try again."
  render :new, status: :unprocessable_entity  # frame-safe, preserves input
end
```

## Configuration

Reads Rails credentials; verification no-ops unless BOTH keys are present (dev/test are zero-config):

```yaml
turnstile:
  site_key: ...
  secret_key: ...
  invisible_site_key: ...    # only if you use invisible: true
  invisible_secret_key: ...
```

Create Managed-mode (and optionally invisible-mode) widgets in the Cloudflare dashboard or via API. Development can use Cloudflare's always-pass test keys. Invisible mode requires referencing Cloudflare's Turnstile Privacy Addendum in your privacy policy.

## Behavior worth knowing

- Fails open on Cloudflare outages (2s/3s timeouts, under a 20s rack-timeout budget); a blank token is rejected without an HTTP call.
- The siteverify `action` is enforced per form name: a token minted on one widget can't be spent on another endpoint.
- The Stimulus controller is Turbo-safe: container cleared around Turbo caching (TurnstileError 300030), script-load `onerror` recovery, no render-after-disconnect, and a fresh widget after a Turbo morph (e.g. a form re-rendered with 422 on a page using `turbo_refreshes_with method: :morph`).
- Users who block challenges.cloudflare.com cannot pass (fail closed by nature of CAPTCHAs) -- keep failure paths friendly.

## Tests

```ruby
require "verify_human/test_helpers"   # needs WebMock

include HumanVerification::TestHelpers
with_human_verification_configured { ... }
stub_human_verification(success: true, action: "sign_in")
stub_human_verification_outage
```

## Contributing

Bug reports are welcome as [GitHub issues](https://github.com/killbridge/verify_human/issues). I don't accept pull requests: the gem stays as opinionated as it is, so please fork it if you want it to work differently.

## Releasing

Bump `VerifyHuman::VERSION`, tag `vX.Y.Z`, push the tag. GitHub Actions publishes to GitHub Packages, where my own apps consume it via:

```ruby
source "https://rubygems.pkg.github.com/killbridge" do
  gem "verify_human"
end
```

## License

MIT. See [LICENSE](LICENSE).
