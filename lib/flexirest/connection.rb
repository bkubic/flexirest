require 'faraday'

module Flexirest

  class TimeoutException < StandardError ; end
  class ConnectionFailedException < StandardError ; end

  class Connection
    attr_accessor :session, :base_url

    def initialize(base_url)
      @base_url                      = base_url
      @session                       = new_session
    end

    def reconnect
      @session         = new_session
    end

    def headers
      @session.headers
    end

    def make_safe_request(path, &block)
      block.call
    rescue Faraday::Error::TimeoutError
      raise Flexirest::TimeoutException.new("Timed out getting #{full_url(path)}")
    rescue Faraday::Error::ConnectionFailed
      begin
        reconnect
        block.call
      rescue Faraday::Error::ConnectionFailed
        raise Flexirest::ConnectionFailedException.new("Unable to connect to #{full_url(path)}")
      end
    end

    def get(path, options={})
      set_defaults(options)
      make_safe_request(path) do
        @session.get(path) do |req|
          set_per_request_timeout(req, options) if options[:timeout]
          req.headers = req.headers.merge(options[:headers])
          sign_request(req, options[:api_auth])
        end
      end
    end

    def put(path, data, options={})
      set_defaults(options)
      make_safe_request(path) do
        @session.put(path) do |req|
          set_per_request_timeout(req, options) if options[:timeout]
          req.headers = req.headers.merge(options[:headers])
          req.body = data
          sign_request(req, options[:api_auth])
        end
      end
    end

    def patch(path, data, options={})
      set_defaults(options)
      make_safe_request(path) do
        @session.patch(path) do |req|
          set_per_request_timeout(req, options) if options[:timeout]
          req.headers = req.headers.merge(options[:headers])
          req.body = data
          sign_request(req, options[:api_auth])
        end
      end
    end

    def post(path, data, options={})
      set_defaults(options)
      make_safe_request(path) do
        @session.post(path) do |req|
          set_per_request_timeout(req, options) if options[:timeout]
          req.headers = req.headers.merge(options[:headers])
          req.body = data
          sign_request(req, options[:api_auth])
        end
      end
    end

    def delete(path, data, options={})
      set_defaults(options)
      make_safe_request(path) do
        @session.delete(path) do |req|
          set_per_request_timeout(req, options) if options[:timeout]
          req.headers = req.headers.merge(options[:headers])
          req.body = data
          sign_request(req, options[:api_auth])
        end
      end
    end

    private

    def set_per_request_timeout(req, options)
      req.options.timeout = options[:timeout].to_i
      req.options.open_timeout = options[:timeout].to_i
    end

    def new_session
      Faraday.new({url: @base_url}, &Flexirest::Base.faraday_config)
    end

    def full_url(path)
      @session.build_url(path).to_s
    end

    def set_defaults(options)
      options[:headers]   ||= {}
      options[:api_auth]  ||= {}
      return options
    end

    def sign_request(request, api_auth)
      return if api_auth[:api_auth_access_id].nil? || api_auth[:api_auth_secret_key].nil?
      ApiAuth.sign!(
        request,
        api_auth[:api_auth_access_id],
        api_auth[:api_auth_secret_key])
    end
  end
end
