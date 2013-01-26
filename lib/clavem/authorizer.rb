# encoding: utf-8
#
# This file is part of the clavem gem. Copyright (C) 2013 and above Shogun <shogun_panda@me.com>.
# Licensed under the MIT license, which can be found at http://www.opensource.org/licenses/mit-license.php.
#

# A local callback server for oAuth web-flow.
module Clavem
  # Exceptions used by {Authorizer Authorizer}.
  module Exceptions
    # This exception is raised whether an error occurs.
    class Failure < ::Exception
    end

    # This exception is raised if the timeout expired.
    class Timeout < ::Exception
    end

    # This exception is raised if the authorization was denied.
    class AuthorizationDenied < ::RuntimeError
    end
  end

  # A class to handle oAuth authorizations.
  #
  # @attr [String] url The URL where to send the user to start authorization..
  # @attr [String] ip The IP address on which listening for replies. Default is `127.0.0.1`.
  # @attr [Fixnum] port The port on which listening for replies. Default is `2501`.
  # @attr [String] command The command to open the URL. `{{URL}}` is replaced with the specified URL. Default is `open "{{URL}}"`.
  # @attr [String] title The title for response template. Default is `Clavem Authorization`.
  # @attr [String] template Alternative template to show progress in user's browser.
  # @attr [Fixnum] timeout The amount of seconds to wait for response from the remote endpoint before returning a failure. Default is `0`, which means *disabled*.
  # @attr [Proc] response_handler A Ruby block to handle response and check for success. @see {#default_response_handler}.
  # @attr [String] token The token obtained by the remote endpoint.
  # @attr [Symbol] token The status of the request. Can be `:success`, `:denied`, `:failure` and `:waiting`.
  # @attr [R18N::Translation] localizer A localizer object.
  class Authorizer
    include R18n::Helpers
    attr_accessor :url
    attr_accessor :ip
    attr_accessor :port
    attr_accessor :command
    attr_accessor :title
    attr_accessor :template
    attr_accessor :timeout
    attr_accessor :response_handler
    attr_accessor :token
    attr_accessor :status
    attr_accessor :i18n

    # Returns a unique (singleton) instance of the authorizer.
    #
    # @param url [String] The URL where to send the user to start authorization..
    # @param ip [String] The IP address on which listening for replies. Default is `127.0.0.1`.
    # @param port [Fixnum] The port on which listening for replies. Default is `2501`.
    # @param command [String|nil] The command to open the URL. `{{URL}}` is replaced with the specified URL. Default is `open "{{URL}}"`.
    # @param title [String|nil] The title for response template. Default is `Clavem Authorization`
    # @param template [String|nil] Alternative template to show progress in user's browser.
    # @param timeout [Fixnum] The amount of seconds to wait for response from the remote endpoint before returning a failure. Default is `0`, which means *disabled*.
    # @param response_handler [Proc] A Ruby block to handle response and check for success. See {#default_response_handler}.
    # @param force [Boolean] If to force recreation of the instance.
    # @return [Authorizer] The unique (singleton) instance of the authorizer.
    def self.instance(url, ip = "127.0.0.1", port = 2501, command = nil, title = nil, template = nil, timeout = 0, force = false, &response_handler)
      @instance = nil if force
      @instance ||= Clavem::Authorizer.new(url, ip, port, command, title, template, timeout, &response_handler)
      @instance
    end

    # Creates a new authorizer.
    #
    # @param url [String] The URL where to send the user to start authorization..
    # @param ip [String] The IP address on which listening for replies. Default is `127.0.0.1`.
    # @param port [Fixnum] The port on which listening for replies. Default is `2501`.
    # @param command [String|nil] The command to open the URL. `{{URL}}` is replaced with the specified URL. Default is `open "{{URL}}"`.
    # @param title [String|nil] The title for response template. Default is `Clavem Authorization`
    # @param template [String|nil] Alternative template to show progress in user's browser.
    # @param timeout [Fixnum] The amount of seconds to wait for response from the remote endpoint before returning a failure. Default is `0`, which means *disabled*.
    # @param response_handler [Proc] A Ruby block to handle response and check for success. See {#default_response_handler}.
    # @return [Authorizer] The new authorizer.
    def initialize(url, ip = "127.0.0.1", port = 2501, command = nil, title = nil, template = nil, timeout = 0, &response_handler)
      @url = url
      @ip = ip.present? ? ip : "127.0.0.1"
      @port = port#[port.to_integer, 2501].max
      @command = command.present? ? command : "open \"{{URL}}\""
      @title = title.present? ? title : "Clavem Authorization"
      @template = template.present? ? template : File.read(File.dirname(__FILE__) + "/template.html.erb")
      @timeout = [timeout.to_integer, 0].max
      @response_handler = response_handler

      @token = nil
      @status = :waiting
      @compiled_template ||= ::ERB.new(@template)
      @i18n = t
      @timeout_expired = false
      @timeout_thread = nil

      self
    end

    # Starts the authorization flow.
    #
    # @return [Authorizer] The authorizer.
    def authorize
      @status = :waiting

      begin
        # Setup stuff
        setup_webserver
        setup_interruptions_handling
        setup_timeout_handling

        # Open the endpoint then start the server
        open_endpoint
        @server.start

        raise Clavem::Exceptions::Timeout.new if @timeout_expired
      rescue Clavem::Exceptions::Timeout => t
        @status = :failure
        raise t
      rescue => e
        @status = :failure
        raise Clavem::Exceptions::Failure.new("Cannot handle response: #{e.to_s}")
      ensure
        cleanup
      end

      raise Clavem::Exceptions::AuthorizationDenied.new if @status == :denied
      self
    end

    # Handles a response from the remote endpoint.
    #
    # @param [Authorizer] authorizer The current authorizer.
    # @param [WEBrick::HTTPRequest] request The request that the remote endpoint made to notify authorization status.
    # @param [WEBrick::HTTPResponse] response The request to send to the browser.
    # @return [String|nil] The oAuth access token. Returning `nil` means *authorization denied*.
    def default_response_handler(authorizer, request, response)
      request.query['oauth_token'].ensure_string
    end

    private
      # Open the remote endpoint
      def open_endpoint
        # Open the oAuth endpoint into the browser
        begin
          system(@command.gsub("{{URL}}", @url))
        rescue => e
          raise Clavem::Exceptions::Failure("Cannot open URL @url: #{e.to_s}")
        end
      end

      # Handle interruptions for the process.
      def setup_interruptions_handling
        ["INT", "TERM", "KILL"].each {|signal| trap(signal){ @server.shutdown if @server } }
      end

      # Handle timeout for the response.
      def setup_timeout_handling
        if @timeout > 0 then
          @timeout_thread = Thread.new do
            sleep @timeout
            @timeout_expired = true
            Process.kill("TERM", 0)
          end
        end
      end

      # Prepare the webserver for handling the response.
      def setup_webserver
        @server = ::WEBrick::HTTPServer.new(BindAddress: @ip, Port: @port, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [nil, nil])

        @server.mount_proc '/' do |request, response|
          @token = @response_handler ? @response_handler.call(self, request, response) : self.default_response_handler(self, request, response)

          if @status == :waiting then
            if @token.present? then
              @status = :success
              response.status = 200
            else
              @status = :denied
              response.status = 500
            end

            response.body = @compiled_template.result(binding)
            @server.shutdown
          end
        end
      end

      # Cleans up resources
      def cleanup
        @timeout_thread.exit if @timeout_thread
        @server.shutdown if @server
        ["INT", "TERM", "KILL"].each {|signal| trap(signal, "DEFAULT") }
      end
  end
end