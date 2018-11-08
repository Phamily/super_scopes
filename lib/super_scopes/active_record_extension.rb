require 'super_scopes/param_set'

module SuperScopes
  module ActiveRecordExtension
    def hydratable(opts)
      class << self
        attr_accessor :hydratable_scopes
        attr_accessor :hydratable_associations
      end

      @hydratable_scopes       = opts[:available_scopes]       || {}
      @hydratable_associations = opts[:available_associations] || {}

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
      ar_rel = ar_rel.includes(hydratable_param_set.ar_includes) if hydratable_param_set.ar_includes.present?

      hydratable_param_set.scopes.reduce(ar_rel) { |chain, (scope_name, scope_args)| chain.send(scope_name, scope_args.symbolize_keys!) }
    end

  protected

    def all_scopes_exist?
      hydratable_scopes.keys.all? { |scope_name| respond_to?(scope_name) }
    end

  end
end
