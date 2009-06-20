module Voorhees 
  
  module Resource
    
    def self.included(base)
      base.extend ClassMethods    
      base.send :include, InstanceMethods
      
      base.instance_eval do
        attr_accessor :raw_json, :json_hierarchy
      end
    end    
    
    module ClassMethods
      def new_from_json(json, hierarchy=nil)
        obj = self.new
        obj.raw_json       = json
        obj.json_hierarchy = hierarchy
        obj
      end
      
      def json_service(name, request_options={})
        (class << self; self; end).instance_eval do
          define_method name do |*args|
            params = args[0]
            json_request do |r|
              r.parameters = params if params.is_a?(Hash)
              request_options.each do |option, value|
                r.send("#{option}=", value)
              end
            end
          end
        end
      end
      
      def json_request(klass=nil)
        request = Voorhees::Request.new(klass || self)
        yield request
        request.perform.to_objects
      end
    end
    
    module InstanceMethods
      
      def json_attributes
        @json_attributes ||= @raw_json.keys.collect{|x| x.to_sym}
      end
      
      def json_request
        self.class.json_request do |r|
          yield r
        end
      end
      
      def method_missing(*args)
        method_name = args[0]
        
        if json_attributes.include?(method_name)
          value = value_from_json(method_name)
          build_methods(method_name, value)
          return value
        end
        
        if method_name.to_s =~ /(.+)=$/ && json_attributes.include?($1.to_sym)
          build_methods($1, args[1])
          return
        end
        
        super
      end
      
      private
        
        def value_from_json(method_name)
          item = raw_json[method_name.to_s]
          
          if json_hierarchy && klass = json_hierarchy[method_name] 
            klass = Object.const_get(klass.to_s.pluralize.classify) if klass.is_a?(Symbol)
          end
          
          if item.is_a?(Array)
            return build_collection_from_json(method_name, item, klass)
          else
            return build_item(item, klass)
          end
        end
        
        def build_methods(name, value)
          self.instance_variable_set("@#{name}".to_sym, value)
          
          instance_eval "          
            def #{name}
              @#{name} ||= value_from_json(:#{name})
            end
          
            def #{name}=(val)
              @#{name} = val
            end
          "
        end
        
        def build_item(json, klass)
          if klass
            raise Voorhees::NotResourceError.new unless klass.respond_to?(:new_from_json)
            klass.new_from_json(json)
          else
            json
          end
        end
        
        def build_collection_from_json(name, json, klass)
          klass = Object.const_get(name.to_s.classify)
          json.collect do |item|
            klass.new_from_json(json)
          end
        rescue NameError
          json
        end
      
    end
    
  end
  
end