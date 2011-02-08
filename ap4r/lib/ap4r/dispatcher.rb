# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'yaml'
require 'thread'
require 'pp'
require 'active_support'

require 'uri'
require 'net/http'
require 'xmlrpc/client'
require 'soap/wsdlDriver'

module Ap4r

  # Represents a group of dispatchers.
  # Responsibilities are follows:
  # - polls target queues,
  # - gets messages from queues, and
  # - calls a <tt>Dispatchers::Base</tt>'s instance.
  class Dispatchers

    attr_reader :config, :group
    @@sleep_inverval = 0.1
    @@logger = nil

    def self.logger
      @@logger
    end

    # storage for <tt>Dispatchers::Base</tt>'s subclasses.
    @@subclasses = {}

    # Stores +klass+ for a dispatch mode +mode+
    # Each +klass+ is used to create instances to handle dispatching messages.
    def self.register_dispatcher_class(mode, klass)
      @@subclasses[mode] = klass
    end

    # Sum of each dispatcher's target queues.
    def targets
      @dispatch_targets
    end

    def initialize(queue_manager, config, logger_obj)
      @qm = queue_manager
      @config = config  # (typically) dispatcher section of queues.cfg
      @@logger ||= logger_obj
      raise "no configuration specified" unless @config
      @group = ThreadGroup.new
      # TODO: needs refinement 2007/05/30 by shino
      @dispatch_targets = ""
      @balancers = []
    end

    # Starts every dispatcher.
    # If an exception is detected, this method raise it through with logging.
    #
    def start
      begin
        logger.info{ "about to start dispatchers with config\n#{@config.to_yaml}" }
        @config.each{ |conf|
          balancer = ::Ap4r::Balancer.new(conf["balancer"], @@logger)
          balancer.start
          @balancers << balancer
          conf["threads"].to_i.times { |index|
            Thread.fork(@group, conf, index, balancer){|group, conf, index, balancer|
              dispatching_loop(group, conf, index, balancer)
            }
          }
          @dispatch_targets.concat(conf["targets"]).concat(';')
          logger.debug{ "dispatch targets are : #{@dispatch_targets}" }
        }
        logger.info "queue manager has forked dispatchers"
      rescue Exception => err
        logger.warn{"Error in starting dipatchers #{err}"}
        logger.warn{err.backtrace.join("\n")}
        raise err
      end
    end

    # Stops every dispatcher.
    # Current implementation makes just dying flags up.
    # Some threads don't stop quickly in some cases such as blocking at socket read.
    #--
    # TODO: needs forced mode? 2007/05/09 by shino
    def stop
      logger.info{"stop_dispatchers #{@group}"}
      return unless @group
      @group.list.each {|d| d[:dying] = true}
      @group.list.each {|d| d.join }
      @dispatch_targets = ""
      @balancers.each { |p| p.stop }
    end

    private

    # Creates and returns an appropriate instace.
    # If no class for +dispatch_mode+, raises an exception.
    def get_dispather_instance(dispatch_mode, message, conf_per_targets)
      klass = @@subclasses[dispatch_mode]
      raise "undefined dispatch mode #{message.headers[:mode]}" unless klass
      klass.new(message, conf_per_targets)
    end

    # Defines the general structure for each dispatcher thread
    # from begging to end.
    def dispatching_loop(group, conf, index, balancer)
      group.add(Thread.current)
      mq = ::ReliableMsg::MultiQueue.new(conf["targets"])
      logger.info{ "start dispatcher: targets= #{mq}, index= #{index})" }
      until Thread.current[:dying]
        # TODO: change sleep interval depending on last result? 2007/05/09 by shino
        sleep @@sleep_inverval
        # logger.debug{ "try dispatch #{mq} #{mq.name}" }
        # TODO: needs timeout?, 2006/10/16 shino
        begin
          balancer.get { |host, port|
            mq.get{|m|
              unless m
                logger.debug{"message is nul"}
                break
              end
              m.headers[:target_url] = begin
                                         uri = URI.parse(m.headers[:target_url])
                                         uri.host = host
                                         uri.port = port
                                         uri.to_s
                                       end 
              logger.debug{"dispatcher get message\n#{m.to_yaml}"}
              response = get_dispather_instance(m.headers[:dispatch_mode], m, conf).call
              logger.debug{"dispatcher get response\n#{response.to_yaml}"}
            }
          }
        rescue Exception => err
          logger.warn("dispatch err #{err.inspect}")
          logger.warn(err.backtrace.join("\n"))
        end
      end
      logger.info{"end dispatcher #{mq} (index #{index})"}
    end

    def logger
      @@logger
    end

    # A base class for dispathcer classes associated with each <tt>dispatch_mode</tt>.
    # Responsibilities of subclasses are to implement following methods, only +invoke+
    # is mandatory and others are optional (no operations by default).
    # * +modify_message+ to preprocess a message, e.g. rewirte URL or discard message.
    # * +invoke+ to execute main logic, e.g. HTTP POST call. *mandatory*
    # * +validate_response+ to judge whether +invoke+ finished successfully.
    # * +response+ to return the result of +invoke+ process.
    class Base

      # Difine a constant +DISPATCH_MODE+ to value 'mode_symbol' and
      # add self to a Converters list.
      def self.dispatch_mode(mode_symbol)
        self.const_set(:DISPATCH_MODE, mode_symbol)
        ::Ap4r::Dispatchers.register_dispatcher_class(mode_symbol, self)
      end

      # Takes
      # * +message+: from a queue
      # * +conf+: configuration from dispatchers section
      #--
      # TODO: Subclass should have +conf+ instead of instance? 2007/06/06 by shino
      def initialize(message, conf)
        @message = message
        @conf = conf
      end

      # Entry facade for each message processing.
      # Modifies, invokes (maybe remote), validates, and responds.
      def call
        # TODO: rename to more appropriate one 2007/05/10 by shino
        self.modify_message
        logger.debug{"Ap4r::Dispatcher after modification\n#{@message.to_yaml}"}
        self.invoke
        self.validate_response
        self.response
      end

      # Modifies message.
      # Now only URL modification is implemented.
      def modify_message
        modification_rules = @conf["modify_rules"]
        return unless modification_rules
        modify_url(modification_rules)
      end

      # Main logic of message processing.
      # Maybe calls remote, e.g. HTTP request.
      def invoke
        # TODO: rename to more appropriate one 2007/05/10 by shino
        raise 'must be implemented in subclasses'
      end

      def validate_response
        # nop
      end

      # Returns response.
      # The return value is also the return value of +call+ method.
      # By default impl, the instance variable <tt>@response</tt> is used.
      def response
        @response
      end

      private
      def logger
        ::Ap4r::Dispatchers.logger
      end

      # Modifies <tt>:target_url</tt> according to a rule.
      # TODO: +proc+ in configuration is eval'ed every time. 2007/06/06 by shino
      def modify_url(modification_rules)
        proc_for_url = modification_rules["url"]
        return unless proc_for_url

        url = URI.parse(@message.headers[:target_url])
        eval(proc_for_url).call(url)
        @message.headers[:target_url] = url.to_s
      end
    end

    # Dispatches via a raw HTTP protocol.
    # Current implementation uses only a POST method, irrespective of
    # <tt>options[:target_method]</tt>.
    #
    # Determination of "success" is two fold:
    # * status code should be exactly 200, other codes (including 201-2xx) are
    #   treated as error, and
    # * body should include a string "true"
    #
    class Http < Base
      dispatch_mode :HTTP

      def invoke
        # TODO: should be added some request headers 2006/10/12 shino
        #       e.g. X-Ap4r-Version, Accept(need it?)
        # TODO: Now supports POST only, 2006/10/12 shino
        @response = nil
        uri = URI.parse(@message[:target_url])
        headers = make_header

        Net::HTTP.start(uri.host, uri.port) do |http|
          # TODO: global configuration over dispatchers for each protocol should be considered, 2008/02/06 by kiwamu
          # TODO: http open timeout should be considered, 2008/02/06 by kiwamu
          if @conf['http'] && @conf['http']['timeout']
            http.read_timeout = @conf['http']['timeout']
            logger.info "set HTTP read timeout to #{http.read_timeout}s"
          end
          @response, = http.post(uri.path, @message.object, headers)
        end
      end

      def make_header
        headers = { }
        @message.headers.map do |k,v|
          s = StringScanner.new(k.to_s)
          s.scan(/\Ahttp_header_/)
          headers[s.post_match] = v if s.post_match
        end
        headers
      end

      def validate_response
        logger.debug{"response status [#{@response.code} #{@response.message}]"}
        validate_response_status(Net::HTTPOK)
        validate_response_body(/true/)
      end

      # Checks whether the response status is a kind of +status_kind+.
      # +status_kind+ should be one of <tt>Net::HTTPRespose</tt>'s subclasses.
      def validate_response_status(status_kind)
        #TODO: make the difinition of success variable, 2006/10/13 shino
        unless @response.kind_of?(status_kind)
          error_message = "HTTP Response FAILURE, " +
            "status [#{@response.code} #{@response.message}]"
          logger.error(error_message)
          logger.info{@response.to_yaml}
          #TODO: must create AP4R specific Exception class, 2006/10/12 shino
          raise StandardError.new(error_message)
        end
      end

      # Checks whether the response body includes +pattern+.
      # +pattern+ should be a regular expression.
      def validate_response_body(pattern)
        unless @response.body =~ pattern
          error_message = "HTTP Response FAILURE, status" +
            " [#{@response.code} #{@response.message}], body [#{@response.body}]"
          #TODO: Refactor error logging, 2006/10/13 shino
          logger.error(error_message)
          logger.info{@response.to_yaml}
          #TODO: must create AP4R specific Exception class, 2006/10/12 shino
          raise StandardError.new(error_message)
        end
      end

    end

    # Dispatches via XML-RPC protocol.
    # Uses +XMLRPC+ library.
    #
    # The call result is judged as
    # * "failure" if the first element of <tt>XMLRPC::Client#call2</tt> result
    #   is false, and
    # * "success" otherwise.
    #
    class XmlRpc < Base
      dispatch_mode :XMLRPC

      def invoke
        endpoint = @message[:target_url]
        client = XMLRPC::Client.new2(endpoint)
        @success, @response = client.call2(@message[:target_action], @message.object)
      end

      def validate_response
        raise @response unless @success
      end
    end

    # Dispatches via SOAP protocol.
    # Uses +SOAP+ library.
    #
    # The call result is judged as
    # * "success" if <tt>SOAP::WSDLDrive#send</tt> finishes without an exception, and
    # * "failuar" otherwise.
    #
    class SOAP < Base
      dispatch_mode :SOAP

      def invoke
        # TODO: nice to cache drivers probably 2007/05/09 by shino
        driver = ::SOAP::WSDLDriverFactory.new(@message[:target_url]).create_rpc_driver
        driver.send(@message[:target_action], @message.object)
      end
    end

    # Dispatches via druby protocol with the implementation DRb.
    #
    # The call result is judged as
    # * "success" if finishes normally (without an exception)
    # * "failuer" if finishes with an exception
    #
    class Druby < Base
      dispatch_mode :druby

      def invoke
        object = DRbObject.new_with_uri(@message[:target_url])
        object.method_missing(@message[:target_method].to_sym, @message.object)
      end
    end

  end
end
