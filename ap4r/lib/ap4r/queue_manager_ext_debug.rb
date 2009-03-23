# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'drb/drb'

module ReliableMsg #:nodoc:
  class QueueManager
    attr_reader :store, :transactions, :mutex, :config, :dispatchers, :carriers

    # Accepts ruby code as a string, evaluates it on +self+,
    # and returns the result as a formatted string.
    # Formats can be one of followings.
    # * <tt>:inspect</tt> : default value
    # * <tt>:yaml</tt>
    # * <tt>:json</tt>
    # * <tt>:xml</tt>
    # Apart from <tt>:inspect</tt>, format can fail depending on 
    # the result object.
    def eval_to_inspect code, inspect_mode = :inspect
      # TODO: too sloppy implementation
      result = Thread.new(code, inspect_mode){ |c, mode|
        $SAFE = 4
        result = self.instance_eval(c)
      }.value
      case inspect_mode
      when :inspect
        result.inspect
      when :yaml
        result.to_yaml
      when :json
        result.to_json
      when :xml
        result.to_xml
      else
        result.inspect
      end
    end
    alias e2i eval_to_inspect

    # Checks queues are all "empty".
    #
    # "Empty" means no messages in transaction and
    # all queues but <tt>$dlq</tt> are empty.
    def no_active_message?
      @transactions.size.zero? && @store.queues.all?{|(q, ms)| q == "$dlq" ||  ms.size.zero? }
    end
  end
  
  module MessageStore #:nodoc:
    class Base
      include DRbUndumped
      attr_reader :mutex, :queues, :topics, :cache

      alias activate_original activate

      def activate
        activate_original
        @mutex.extend DRbUndumped
        # TODO: queues/topics/cache should be DRbUndumped? 2007/06/06 by shino
        # @queues.extend DRbUndumped
        # @topics.extend DRbUndumped
        # @cache.extend DRbUndumped
      end

    end
  end
end

