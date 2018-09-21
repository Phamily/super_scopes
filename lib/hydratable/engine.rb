# require 'hydratable/param_set'
require 'hydratable/action_controller_extension'
require 'hydratable/active_record_extension'

module Hydratable
  class Engine < ::Rails::Engine

    isolate_namespace Hydratable

    ActiveSupport.on_load :active_record do
      extend Hydratable::ActiveRecordExtension
    end

    ActiveSupport.on_load :action_controller do
      include Hydratable::ActionControllerExtension
    end

  end
end