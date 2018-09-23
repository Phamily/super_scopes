module Hydratable
  class ParamSet

    attr_accessor :model_class
    attr_accessor :serialization_params
    attr_accessor :scope_args

    attr_accessor :fields
    attr_accessor :scopes
    attr_accessor :ar_includes
    attr_accessor :jsonapi_includes
    attr_accessor :request_ctx

    def initialize(a_model_class, serialization_params, scope_args = {}, ctx)
      @model_class          = a_model_class
      @request_ctx          = ctx
      @fields               = {}
      @applied_scopes       = []
      @serialization_params = serialization_params.symbolize_keys!
      @scope_args           = scope_args.symbolize_keys!
      @table_name           = a_model_class.name.downcase.to_sym
      @fields[@table_name]  = assign_fields

      @scopes               = {}
      @ar_includes          = {}
      @jsonapi_includes     = []
      init_scopes_and_includes
    end


  protected
    def assign_fields
      serialization_params.keys - model_class.hydratable_scopes.keys - model_class.hydratable_associations.keys
    end

    def init_scopes_and_includes
      serialization_params.each do |param_field_name, param_field_args|
        if (scope_to_apply = find_scope(param_field_name)).present?
          raise ArgumentError, "Multiple scopes found for field: #{param_field_name}. " unless scope_to_apply.length == 1
          assign_scopes(scope_to_apply, param_field_name, param_field_args)
        end

        if (association_to_include = find_association(param_field_name)).present?
          assign_associations(association_to_include, {param_field_name => param_field_args})
        end
      end
    end

    def assign_scopes(scope, param_field_name, param_field_args)
      scope_name = scope.keys.first
      return if @applied_scopes.include? scope_name
      @applied_scopes << scope_name

      if param_field_name.to_s == scope_name.to_s
        @fields[@table_name] += scope[scope_name][:fields] if scope[scope_name][:fields]
        scope_args = param_field_args
      end
      @scopes[scope_name] = generate_args_for_scope(scope, scope_name, scope_args)
    end

    def find_scope(field)
      model_class.hydratable_scopes.select do |scope_name, scope_attrs|
        scope_name.to_s == field.to_s ||
        (scope_attrs[:fields] && scope_attrs[:fields].include?(field))
      end
    end

    def generate_args_for_scope(scope, scope_name, input_args = {})

      scope_args = scope[scope_name][:args] || []

      treat_input_as_arg = scope_args.reject { |arg| arg[:type] == :internal }.length == 1

      scope_args.each_with_object({}) do |default_arg, ret|
        arg_name = default_arg[:name]
        arg_val  = get_arg_value(default_arg, input_args, treat_input_as_arg)
        ret.send :[]=, arg_name, arg_val
      end
    end

    def get_arg_value(default_arg, input_args, treat_input_as_arg)
      if default_arg[:type] == :internal
        # Always use default for internal arguments + bind request context
        raise 'Request Context must be supplied to internal arguments' unless request_ctx.present?
        request_ctx.instance_eval(&default_arg[:default])

      elsif input_args.present?
        if input_args.is_a?(Hash)
          input_args.with_indifferent_access[default_arg[:name]]
        elsif treat_input_as_arg
          input_args
        else
          raise ArgumentError, 'Supplied non-hash to scope with >1 argument'
        end
      else
        # Call default args
        default_arg[:default].is_a?(Proc) ? default_arg[:default].call() : default_arg[:default]
      end
    end

    def assign_associations(association, requested_fields)
      @ar_includes = @ar_includes.merge deep_build_association_includes(association, requested_fields)
    end

    def find_association(field)
      model_class.hydratable_associations.select { |scope_name, scope_attrs| scope_name.to_s == field.to_s }
    end

    def deep_build_association_includes(association_definition, requested_fields = {}, prefix = '')
      association_key  = association_definition.keys.first
      association_name = association_definition[association_key][:name]

      fields = requested_fields.deep_find(association_key)
      if fields && (included_fields = fields.select { |k, v| v == true }.try(:keys))
        prefix = "#{prefix.to_s + '.' if prefix.present?}#{association_name}".to_sym
        if included_fields.present?
          # ASK: Does this need to refer to the record_type (not assocation_name) for jsonapi?
          @fields[association_name.to_s.singularize.to_sym] ||= []
          @fields[association_name.to_s.singularize.to_sym]  += included_fields
          @jsonapi_includes << prefix
        end
      end
      return { association_name => {} } unless association_definition[association_key][:associations]
      association_definition[association_key][:associations].each_with_object({}) do |sub_association, ret|
        if requested_fields.deep_find(sub_association[0]).present?
          ret[association_name] = deep_build_association_includes({sub_association[0] => sub_association[1]}, requested_fields, prefix)
        else
          ret[association_name] = {}
        end
      end
    end
  end
end

# Taken from:
#   https://stackoverflow.com/questions/8301566/find-key-value-pairs-deep-inside-a-hash-containing-an-arbitrary-number-of-nested
class Hash
  def deep_find(key, object=self, found=nil)
    if object.respond_to?(:key?) && object.key?(key)
      return object[key]
    elsif object.is_a? Enumerable
      object.find { |*a| found = deep_find(key, a.last) }
      return found
    end
  end
end