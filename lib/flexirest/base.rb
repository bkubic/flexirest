module Flexirest
  class Base
    include Mapping
    include Configuration
    include RequestFiltering
    include Validation
    include Caching
    include Recording
    include AttributeParsing
    include Associations

    attr_accessor :_status
    attr_accessor :_etag
    attr_accessor :_headers

    instance_methods.each do |m|
      next unless %w{display presence load require hash untrust trust freeze method enable_warnings with_warnings suppress capture silence quietly debugger breakpoint}.map(&:to_sym).include? m
      undef_method m
    end

    def initialize(attrs={})
      @attributes = {}
      @dirty_attributes = Set.new

      raise Exception.new("Cannot instantiate Base class") if self.class.name == "Flexirest::Base"

      attrs.each do |attribute_name, attribute_value|
        attribute_name = attribute_name.to_sym
        @attributes[attribute_name] = parse_attribute_value(attribute_value)
        @dirty_attributes << attribute_name
      end
    end

    def _clean!
      @dirty_attributes = Set.new
    end

    def _attributes
      @attributes
    end

    def _copy_from(result)
      @attributes =  result._attributes
      @_status = result._status
    end

    def dirty?
      @dirty_attributes.size > 0
    end

    def errors
      @attributes[:errors] || (_errors != {} ? _errors : nil)
    end

    def self._request(request, method = :get, params = nil)
      prepare_direct_request(request, method).call(params)
    end

    def self._plain_request(request, method = :get, params = nil)
      prepare_direct_request(request, method, plain:true).call(params)
    end

    def self._lazy_request(request, method = :get, params = nil)
      Flexirest::LazyLoader.new(prepare_direct_request(request, method), params)
    end

    def self.prepare_direct_request(request, method = :get, options={})
      unless request.is_a? Flexirest::Request
        options[:plain] ||= false
        request = Flexirest::Request.new({ url: request, method: method, options: options }, self)
      end
      request
    end

    def self._request_for(method_name, *args)
      if mapped = self._mapped_method(method_name)
        params = (args.first.is_a?(Hash) ? args.first : nil)
        request = Request.new(mapped, self, params)
        request
      else
        nil
      end
    end

    def [](key)
      @attributes[key.to_sym]
    end

    def []=(key, value)
      @attributes[key.to_sym] = value
      @dirty_attributes << key
    end

    def each
      @attributes.each do |key, value|
        yield key, value
      end
    end

    def inspect
      inspection = if @attributes.any?
                     @attributes.collect { |key, value|
                       "#{key}: #{value_for_inspect(value)}"
                     }.compact.join(", ")
                   else
                     "[uninitialized]"
                   end
      inspection += "#{"," if @attributes.any?} ETag: #{@_etag}" unless @_etag.nil?
      inspection += "#{"," if @attributes.any?} Status: #{@_status}" unless @_status.nil?
      inspection += " (unsaved: #{@dirty_attributes.map(&:to_s).join(", ")})" if @dirty_attributes.any?
      "#<#{self.class} #{inspection}>"
    end

    def method_missing(name, *args)
      if name.to_s[-1,1] == "="
        name = name.to_s.chop.to_sym
        @attributes[name] = args.first
        @dirty_attributes << name
      else
        name_sym = name.to_sym
        name = name.to_s

        if @attributes.has_key? name_sym
          @attributes[name_sym]
        else
          if name[/^lazy_/] && mapped = self.class._mapped_method(name_sym)
            raise ValidationFailedException.new unless valid?
            request = Request.new(mapped, self, args.first)
            Flexirest::LazyLoader.new(request)
          elsif mapped = self.class._mapped_method(name_sym)
            raise ValidationFailedException.new unless valid?
            request = Request.new(mapped, self, args.first)
            request.call
          elsif self.class.whiny_missing
            raise NoAttributeException.new("Missing attribute #{name_sym}")
          else
            nil
          end
        end
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @attributes.has_key? method_name.to_sym
    end

    def to_hash
      output = {}
      @attributes.each do |key, value|
        if value.is_a? Flexirest::Base
          output[key.to_s] = value.to_hash
        elsif value.is_a? Array
          output[key.to_s] = value.map(&:to_hash)
        else
          output[key.to_s] = value
        end
      end
      output
    end

    def to_json
      output = to_hash
      output.to_json
    end

    private

    def value_for_inspect(value)
      if value.is_a?(String) && value.length > 50
        "#{value[0..50]}...".inspect
      elsif value.is_a?(Date) || value.is_a?(Time)
        %("#{value.to_s(:db)}")
      else
        value.inspect
      end
    end

  end

  class NoAttributeException < StandardError ; end
  class ValidationFailedException < StandardError ; end
  class MissingOptionalLibraryError < StandardError ; end
end
