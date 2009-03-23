# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

module Ap4r::Util #:nodoc:
  # This class is TOO EXPERIMENTAL
  #
  # Client class for +QueueManager+.
  # This class wraps DRb client and provides some helper methods.
  # TODO: many drb calls are executed in a method call such as +list_queues+. 2006/09/22 by shino
  #       ParseTree is perhaps needed. Now ruby-parser is also available?
  class QueueClient
    CONFIG_DIR_DEFAULT = 'config'
    CONFIG_FILE_DEFAULT = 'queues.cfg'

    HOST_DEFAULT = 'localhost'

    DEFAULT_QUEUE_PREFIX = 'queue.test.'
    DEFAULT_QUEUE_SUFFIX = 'default'
    DEFAULT_MULTI_QUEUE = DEFAULT_QUEUE_PREFIX + '*'

    @@config_dir = CONFIG_DIR_DEFAULT
    cattr_accessor :config_dir

    attr_reader :name, :config

    # Creates new client from a configuration file.
    # Some options are supported.
    # * <tt>:host</tt>
    # * <tt>:port</tt>
    # * <tt>:name</tt>
    def initialize(config_file = CONFIG_FILE_DEFAULT,
                   options = {},
                   config_dir = @@config_dir)
      @config = ReliableMsg::Config.new(File.join(config_dir, config_file))
      @config.load_no_create
      @host = options[:host] || @config.drb['host'] || 'localhost'
      @port = options[:port] || @config.drb['port'] || 6438
      @name = (options[:name]).to_sym
      @qm = nil
    end

    def queue_manager
      @qm ||= DRb::DRbObject.new_with_uri(drb_uri)
    end

    def queue_manager_stop
      manager = queue_manager
      begin
        manager.stop
      rescue DRb::DRbConnError => error
        error.message
      end
    end

    def list_queues
      qm.store.queues.keys
    end

    def list_messages(suffix = DEFAULT_QUEUE_SUFFIX,
                      prefix = DEFAULT_QUEUE_PREFIX)
      qm.store.queues[prefix.to_s + suffix.to_s]
    end

    def make_queue(suffix = DEFAULT_QUEUE_SUFFIX,
                   prefix = DEFAULT_QUEUE_PREFIX)
      ReliableMsg::Queue.new(prefix.to_s + suffix.to_s, :drb_uri => drb_uri)
    end

    def queue_get(suffix = DEFAULT_QUEUE_SUFFIX, selector = nil,
                  prefix = DEFAULT_QUEUE_PREFIX, &block)
      q = make_queue suffix, prefix
      q.get selector, &block
    end

    def queue_put(suffix = DEFAULT_QUEUE_SUFFIX,
                  message = nil, prefix = DEFAULT_QUEUE_PREFIX,
                  headers = nil)
      unless message
        t = Time.now
        message = sprintf("test message %s,%s",
                          t.strftime("%Y/%m/%d %H:%M:%S"), t.usec)
      end
      q = make_queue suffix, prefix
      q.put message, headers
    end

    def make_multi_queue multi_queue = DEFAULT_MULTI_QUEUE
      ReliableMsg::MultiQueue.new(multi_queue.to_s, :drb_uri => drb_uri)
    end

    def multi_queue_get(selector = nil,
                        multi_queue = DEFAULT_MULTI_QUEUE, &block)
      mq = make_multi_queue multi_queue, :drb_uri => irm_drb_uri
      mq.get selector, &block
    end

    def drb_uri
      "druby://#{@host}:#{@port}"
    end

    def to_s
      @name.to_s
    end

    alias qm queue_manager
    alias stop queue_manager_stop

    alias lsq list_queues
    alias lsm list_messages

    alias mkq make_queue
    alias qg queue_get
    alias qp queue_put

    alias mkmq make_multi_queue
    alias mqg multi_queue_get

    alias uri drb_uri

  end
end
