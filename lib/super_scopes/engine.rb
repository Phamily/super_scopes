# require 'hydratable/param_set'
require 'super_scopes/action_controller_extension'
require 'super_scopes/active_record_extension'

module SuperScopes
  class Engine < ::Rails::Engine

    isolate_namespace SuperScopes

    ActiveSupport.on_load :active_record do
      extend SuperScopes::ActiveRecordExtension
    end

    ActiveSupport.on_load :action_controller do
      include SuperScopes::ActionControllerExtension
    end

  end
end