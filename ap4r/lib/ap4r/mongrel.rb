# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'mongrel'
require 'cgi'

require 'ap4r'

module Ap4r

  module Mongrel #:nodoc:

    # Gather controls AP4R server.
    class Ap4rConfigurator < ::Mongrel::Configurator

      def stop(needs_restart=false)
        ::ReliableMsg::Client.new.instance_eval do
          qm.stop
        end
        super
        join
      end

      def mswin?
        RUBY_PLATFORM =~ /mswin/
      end

      def remove_pid_file
        return unless @pid_file && File.exists?(@pid_file)
        # TODO: slit exists between pid check and delete 2007/04/16 by shino
        File.delete(@pid_file) if pid_from_file == Process.pid
      end

      def pid_from_file
        File.open(@pid_file) do |file|
          file.read.to_i
        end
      end
    end

    # Implements a handler that can run AP4R.
    # * If the requested exact PATH_INFO exists as a file then serve it.
    # + (Second, access server information or queue/topic API) NOT IMPLEMENTED.
    # * Finally, raise an exception.
    #
    # memo: want to use this handler to take information from AP4R server
    # like mod_status. Message counts and status of threads are useful.
    #
    # TODO not yet implemented 2007/04/09 by shino
    #
    class Ap4rHandler < ::Mongrel::HttpHandler
      attr_reader :files
      @@file_only_methods = ["GET","HEAD"]

      def initialize(options)
        # TODO: needs various modes for easy operations 2007/05/02 by shino
        #        e.g. not to initialize message store, not to start dispatchers, etc.

        # TODO what is "false" here? 2007/04/13 by shinohara
        @files = ::Mongrel::DirHandler.new(options[:docroot], false)
        @tick = Time.now

        # TODO: QueueManager life cycle should be controlled in Configurator? 2007/04/16 by shino
        qm = ::ReliableMsg::QueueManager.new({:config => options[:ap4r_config_file]})
        qm.start
      end

      # * If the requested exact PATH_INFO exists as a file then serve it.
      # * Finally, raise an exception.
      def process(request, response)
        if response.socket.closed?
          return
        end

        path_info = request.params[Mongrel::Const::PATH_INFO]
        get_or_head = @@file_only_methods.include? request.params[Mongrel::Const::REQUEST_METHOD]
        if get_or_head and @files.can_serve(path_info)
          # File exists as-is so serve it up
          @files.process(request,response)
        else
          raise "No file... Sorry" #TODO set 404 status 2007/04/09 by shino
        end
      end

      def log_threads_waiting_for(event)
        if Time.now - @tick > 10
          @tick = Time.now
        end
      end

      # Does the internal reload for Rails.  It might work for most cases, but
      # sometimes you get exceptions.  In that case just do a real restart.
      def reload!
        begin
          #TODO not implemented 2007/04/09 by shino
          raise "not yet implemented!"
        end
      end

    end

    # This class is an experimental implementation of RESTified message API.
    # Send to queue:
    #   using HTTP POST
    #   a message is sent as HTTP body which format is depending on MIME type
    #   (now supported only text/plain)
    #
    #   options are sent as HTTP header which header name is "X-AP4R"
    #   url consists of prefix ("/queues") and queue name
    #
    #
    #   === Request example ===
    #   POST /queues/queue.test HTTP/1.1
    #   Content-Type: text/plain
    #   X-AP4R: dispatch_mode=HTTP, target_method=POST, target_url=http://localhost:3000/async_shop/execute_via_http/
    #
    #   hoge
    #
    #
    #   === Response example ===
    #   HTTP/1.1 200 Ok
    #   Date: The, 11 Dec 2007 17:17:11 GMT
    #
    #   7bb181f0-7ee0-012a-300a-001560abd426
    #
    class Ap4rSendMessageHandler < ::Mongrel::HttpHandler

      def initialize(options)
        @tick = Time.now
        @queues = {}
      end

      def process(request, response)
        if response.socket.closed?
          return
        end

        queue_name = request.params[::Mongrel::Const::PATH_INFO][1..-1]
        header = make_header(request.params["HTTP_X_AP4R"]) # Todo: assign as constant 2007/11/27 by kiwamu

        if "POST".include? request.params[::Mongrel::Const::REQUEST_METHOD]
          begin
            q = if @queues.key? queue_name
                  @queues[queue_name]
                else
                  @queues[queue_name] = ::ReliableMsg::Queue.new(queue_name)
                end
            mid = q.put(request.body.string, header)

            response.start(200) do |head, out|
              head['Content-Type'] = 'text/plain'
              out.write mid
            end
          rescue Exception
            response.start(500) do |head, out|
              head['Content-Type'] = 'text/plain'
              out.write "Failed to send message. #{request.body.string}"
            end
          end
        else
          raise "HTTP method is not POST..." # Todo
        end
      end

      def make_header(x_ap4r_header)
        header = {}
        if x_ap4r_header
          x_ap4r_header.split(',').map do |e|
            key, value = e.strip.split('=')
            if %w(dispatch_mode target_method delivery).include?(key)
              header[key.to_sym] = value.to_sym
            else
              header[key.to_sym] = value
            end
          end
        end
        header
      end

      def log_threads_waiting_for(event)
        if Time.now - @tick > 10
          @tick = Time.now
        end
      end

      # Does the internal reload for Rails.  It might work for most cases, but
      # sometimes you get exceptions.  In that case just do a real restart.
      def reload!
        begin
          #TODO not implemented 2007/04/09 by shino
          raise "not yet implemented!"
        end
      end

    end

    # This class is an experimental implementation of RESTified message API.
    # Subscribe to queue:
    #   using HTTP POST
    #   a message is subscribed as HTTP body
    #
    #   options are sent as HTTP header which header name is "X-AP4R"
    #   (now not supported)
    #
    #   url consists of prefix ("/subscribes") and queue name
    #
    #   response body is now return value of ReliableMsg#inspct
    #   In the future, it will be possible to assign the format by the request header X-AP4R
    #
    #
    #   === Rrequest example ===
    #   POST /subscribes/queue.test HTTP/1.1
    #
    #
    #   === Response example ===
    #   HTTP/1.1 200 Ok
    #   Content-Type: text/plain
    #   Date: The, 11 Dec 2007 17:17:11 GMT
    #
    #   #<ReliableMsg::Message:0x320ec90 @headers={:priority=>0, :created=>1197628231, :expires=>nil, :delivery=>:best_effort, :id=>\"856016b0-8c5d-012a-79f3-0016cb9ad524\", :max_deliveries=>5}, @object=\"hoge\", @id=\"856016b0-8c5d-012a-79f3-0016cb9ad524\">
    #
    class Ap4rSubscribeMessageHandler < ::Mongrel::HttpHandler

      def initialize(options)
        @tick = Time.now
        @queues = {}
      end

      def process(request, response)
        if response.socket.closed?
          return
        end

        queue_name = request.params[::Mongrel::Const::PATH_INFO][1..-1]
        # header = make_header(request.params["HTTP_X_AP4R"]) # Todo: assign as constant 2007/11/27 by kiwamu

        if "POST".include? request.params[::Mongrel::Const::REQUEST_METHOD]
          begin
            q = if @queues.key? queue_name
                  @queues[queue_name]
                else
                  @queues[queue_name] = ::ReliableMsg::Queue.new(queue_name)
                end
            mes = q.get

            response.start(200) do |head, out|
              head['Content-Type'] = 'text/plain'
              out.write mes.inspect
            end
          rescue
            response.start(500) do |head, out|
              head['Content-Type'] = 'text/plain'
              out.write "Failed to get message for #{queue_name}"
            end
          end
        else
          raise "HTTP method is not POST..."
        end
      end

      def make_header(x_ap4r_header)
        header = {}
        if x_ap4r_header
          x_ap4r_header.split(',').map do |e|
            key, value = e.strip.split('=')
            if %w(dispatch_mode target_method delivery).include?(key)
              header[key.to_sym] = value.to_sym
            else
              header[key.to_sym] = value
            end
          end
        end
        header
      end

      def log_threads_waiting_for(event)
        if Time.now - @tick > 10
          @tick = Time.now
        end
      end

      # Does the internal reload for Rails.  It might work for most cases, but
      # sometimes you get exceptions.  In that case just do a real restart.
      def reload!
        begin
          #TODO not implemented 2007/04/09 by shino
          raise "not yet implemented!"
        end
      end

    end

    # This class is an experimental implementation of monitoring API by HTTP.
    # It's possible to get the number of message in an arbitrary queue and
    # the number of (alive/dead) thread of dispatchers.
    #
    #   === Rrequest example ===
    #   GET /mointoring/queues/queue.test HTTP/1.1
    #   GET /mointoring/queues/all HTTP/1.1
    #   GET /mointoring/queues/dlq HTTP/1.1
    #
    #   GET /mointoring/dispatchers/alive_threads HTTP/1.1
    #   GET /mointoring/dispatchers/dead_threads HTTP/1.1
    #
    class Ap4rMonitoringHandler < ::Mongrel::HttpHandler

      def initialize(options)
        @tick = Time.now

        dlq = ReliableMsg::Queue.new "$dlq"
        @qm = dlq.send :qm
      end

      def process(request, response)
        if response.socket.closed?
          return
        end

        target = request.params[::Mongrel::Const::PATH_INFO][1..-1]

        if "GET".include? request.params[::Mongrel::Const::REQUEST_METHOD]
          begin
            # TODO: consider URL for each target, 2008/02/28 by kiwamu
            result = case target
                     when /^queues\/*(\S*)/
                       case queue_name = $1
                       when ""
                         @qm.store.queues.keys.join(" ")
                       when "dlq"
                         @qm.store.queues["$dlq"].size
                       when "all"
                         @qm.store.queues.map{|k,v| v.size}.sum
                       else
                         @qm.store.queues[queue_name].size
                       end
                     when /^dispatchers\/*(\S*)/
                       case $1
                       when "alive_threads"
                         @qm.dispatchers.group.list.size
                       when "dead_threads"
                         diff = @qm.dispatchers.config.map{|d| d["threads"]}.sum - @qm.dispatchers.group.list.size
                         diff > 0 ? diff : 0
                       else
                         raise
                       end
                     else
                       raise
                     end

            response.start(200) do |head, out|
              head['Content-Type'] = 'text/plain'
              out.write result
            end
          rescue
            response.start(500) do |head, out|
              head['Content-Type'] = 'text/plain'
              out.write "Failed to monitor #{target}"
            end
          end
        else
          raise "HTTP method is not GET..."
        end
      end

      # Does the internal reload for Rails.  It might work for most cases, but
      # sometimes you get exceptions.  In that case just do a real restart.
      def reload!
        begin
          #TODO not implemented 2007/04/09 by shino
          raise "not yet implemented!"
        end
      end

    end

  end
end
