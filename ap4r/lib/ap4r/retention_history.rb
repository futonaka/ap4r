# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'active_support'

module ReliableMsg #:nodoc:

  # This class is too much experimental.
  # The aim: for performance monitoring, records unprocessed message count
  # in every queues at some interval.
  class RetentionHistory
    include DRbUndumped

    # to_i method is required for ActiveSupport 2.0 where return value of seconds method
    # is not Fixnum.
    LOOP_INTERVAL = 1.seconds.to_i
    SHELF_LIFE = 10.minutes.to_i
#    SHELF_LIFE = 10.seconds.to_i
    attr_reader :data

    def initialize(qm, logger, config)
      @data = {}
      @qm = qm
      @logger = logger
      @config = config
      @qm.add_lifecycle_listener(self, 'retention')
    end

    def start
      @collector = Thread.start do
        loop do
          begin
            sleep LOOP_INTERVAL
            collect
            sweep
          rescue Exception => ex
            @logger.warn("message retention history (collect) #{ex.inspect}")
            @logger.warn(ex.backtrace.join("\n\t"))
          end
        end
      end
    end

    def stop
      @collector.terminate
    end

    private
    def collect
      @qm.store.queues.each {|name, messages|
        new_data(name, messages.size)
      }
    end

    def new_data(queue_name, count)
      (@data[queue_name.to_sym] ||= []) << [Time.now, count]
    end

    def sweep
      limit = Time.now - SHELF_LIFE
      @data.each do |q, time_count|
        time_count.delete_if {|t,c| t < limit }
      end
    end
  end
end
