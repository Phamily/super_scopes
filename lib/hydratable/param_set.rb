module Hydratable
  class ParamSet

    attr_accessor :model_class
    attr_accessor :serialization_params
    attr_accessor :scope_args

    attr_accessor :fields
    attr_accessor :scopes
    attr_accessor :includes
    attr_accessor :request_ctx

    def initialize(a_model_class, serialization_params, scope_args = {}, ctx)
      @model_class          = a_model_class
      @request_ctx          = ctx
      @fields               = {}
      @includes             = []
      @applied_scopes       = []
      @serialization_params = serialization_params.symbolize_keys!
      @scope_args           = scope_args.symbolize_keys!
      @table_name           = a_model_class.name.downcase.to_sym
      @fields[@table_name]  = assign_fields
      @scopes               = assign_scopes
    end


  protected
    def assign_fields
      serialization_params.keys - model_class.hydratable_scopes.keys - model_class.hydratable_associations.keys
    end

    def assign_scopes
      serialization_params.each_with_object({}) do |(param_field_name, param_field_args), ret|
        next unless (scope_to_apply = find_scope(param_field_name)).present?
        scope_name = scope_to_apply.keys.first

        next if @applied_scopes.include? scope_name
        @applied_scopes << scope_name

        if param_field_name.to_s == scope_name.to_s
          assign_scope_fields(scope_to_apply, param_field_name, param_field_args)
          scope_args = param_field_args
        end

        ret.send :[]=, scope_name, generate_args_for_scope(scope_to_apply, scope_name, scope_args)
      end
    end

    def find_scope(field)
      model_class.hydratable_scopes.select do |scope_name, scope_attrs|
        scope_name.to_s == field.to_s ||
        (scope_attrs[:fields] && scope_attrs[:fields].include?(field))
      end
    end

    def assign_scope_fields(scope, scope_name, scope_args)
      return unless scope[scope_name][:fields]
      # If requested scope is an association (i.e. has table_name set) only add requested fields
      if scope[scope_name][:table]

        table_name = scope[scope_name][:table].name.downcase.to_sym
        @fields[table_name] ||= []

        # if args are a hash assume the 'args' is actually an object with field keys and boolean values
        if scope_args.is_a?(Hash)
          @fields[table_name]  += scope_args.select { |e| e }.keys
        else
          @fields[table_name]  += scope[scope_name][:fields]
        end

        @includes << scope[scope_name][:table].table_name.to_sym
      else
        # Otherwise (i.e. scope is a filter or hydration) add all associated fields
        @fields[@table_name] += scope[scope_name][:fields]
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
      name_      = association_definition.keys.first
      table_name = association_definition[name_][:table_name]
      fields = requested_fields.deep_find(name_)

      if fields && (included_fields = fields.select { |k, v| v == true }.try(:keys))
        prefix = "#{prefix.to_s + '.' if prefix.present?}#{table_name}".to_sym
        if included_fields.present?
          @fields[table_name.to_s.singularize.to_sym] ||= []
          @fields[table_name.to_s.singularize.to_sym]  += included_fields
          @jsonapi_includes << prefix
        end
      end

      return table_name unless association_definition[name_][:associations]
      association_definition[name_][:associations].each_with_object({}) do |sub_association, ret|
        ret[table_name] = deep_build_association_includes({sub_association[0] => sub_association[1]}, requested_fields, prefix)
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