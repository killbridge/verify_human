require_relative "lib/verify_human/version"

Gem::Specification.new do |spec|
  spec.name = "verify_human"
  spec.version = VerifyHuman::VERSION
  spec.authors = ["Marc Köhlbrugge"]
  spec.summary = "Human verification for Rails forms; Cloudflare Turnstile under the hood"
  spec.description = "verify_human class macro, human_verification_tag view helper, and a Turbo-safe Stimulus controller. Interaction-only Managed widgets by default, optional invisible-mode widgets, fail-open verification with tight timeouts, per-form action enforcement."
  spec.homepage = "https://github.com/killbridge/verify_human"
  spec.license = "MIT"
  spec.metadata["allowed_push_host"] = "https://rubygems.pkg.github.com/killbridge"
  spec.required_ruby_version = ">= 3.2"

  spec.files = Dir["{app,config,lib}/**/*", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "faraday", ">= 2.0"
end
