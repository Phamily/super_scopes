require 'hydratable/param_set'

module Hydratable
  module ActiveRecordExtension
    def hydratable(opts)
      class << self
        attr_accessor :hydratable_scopes
      end

      @hydratable_scopes = opts[:available_scopes] || {}

      unless all_scopes_exist?
        raise(ArgumentError, "1 or more scopes is not defined on #{self.class}")
      end
    end

    def hydrate(hydratable_param_set)
      ar_rel = if ActiveRecord::Relation === self
        self
      else
        all
      end
      hydratable_param_set.scopes.reduce(ar_rel) { |chain, (scope_name, scope_args)| chain.send(scope_name, scope_args.symbolize_keys!) }
    end

  protected

    def all_scopes_exist?
      hydratable_scopes.keys.all? { |scope_name| respond_to?(scope_name) }
    end

  end
end
