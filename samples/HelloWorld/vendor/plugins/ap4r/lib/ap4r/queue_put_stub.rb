# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

module Ap4r
  module AsyncHelper
    module Base
      def queued_messages
        return @queued_messages if @queued_messages
        @queued_messages = Hash.new {|hash, key| hash[key] = []}
        return @queued_messages
      end

      private
      def __queue_put(queue_name, message, headers)
        queued_messages[queue_name] << {:headers => headers, :body => message}
      end

    end
  end
end
