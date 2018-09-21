module Hydratable
  module ActionControllerExtension
  protected
    # NB: Filterrific usees this layer to apply default arguments
    #       We should probably resolve preset -> fields here?
    #       Then ParamSet handles mapping fields -> necessary scopes
    def initialize_hydration(model_class, requested_fields, request_ctx)
      Hydratable::ParamSet.new(model_class, requested_fields, request_ctx)
    end
  end
end