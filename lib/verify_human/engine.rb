module VerifyHuman
  # Non-isolated engine: app/controllers/concerns and app/helpers merge into
  # the host app's autoload and helper paths, so apps keep writing
  # `include HumanVerification` and calling `human_verification_tag` with no
  # namespace changes.
  class Engine < ::Rails::Engine
    initializer "verify_human.assets" do |app|
      app.config.assets.paths << root.join("app/assets/javascripts") if app.config.respond_to?(:assets)
    end

    # Pinned under controllers/ so stimulus-loading's lazyLoadControllersFrom
    # discovers and registers the controller exactly like an app-local one.
    initializer "verify_human.importmap", before: "importmap" do |app|
      app.config.importmap.paths << root.join("config/importmap.rb") if defined?(Importmap)
    end
  end
end
