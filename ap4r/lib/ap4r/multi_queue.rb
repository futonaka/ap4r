# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

module ReliableMsg

  # The +MultiQueue+ is a kind of clients.
  # This offers two extentions to <tt>ReliableMsg::Queue</tt>
  # 1. specify multiple target queues, by as comma-separated queue names.
  # 1. specify prefix of a collection of queues by an asterisk at the end.
  # Exapmles:
  # * <tt>"a.b.c"</tt> targets single queue.
  # * <tt>"a.b.c, x.y.z"</tt> targets two queues.
  # * <tt>"a.b.*"</tt> targets a collection of queues such as "a.b.c", "a.b.d", etc.
  # * <tt>"a.b.*, x.y.*"</tt> targets two collections.
  class MultiQueue < Client
    # Creates a new +MultiQueue+ with target queues specified by +multi_queue+.
    # See <tt>ReliableMsg::Queue</tt> for +options+.
    def initialize multi_queue, options = nil
      @multi_queue = multi_queue
      @options = options
    end

    # Gets a message from target queues.
    # Internally, first search a queue with the most stale message,
    # and get a message from the queue by <tt>ReliableMsg::Queue#get</tt>
    def get selector = nil, &block
      queue_name = repeated {|qm|
        qm.stale_queue @multi_queue
      }
      return nil unless queue_name
      queue = Queue.new queue_name, @options
      queue.get selector, &block
    end

    # Returns multi queue expression as +String+.
    def name
      @multi_queue
    end
  end
end
