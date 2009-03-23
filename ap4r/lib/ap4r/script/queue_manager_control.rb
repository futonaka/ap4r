# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'rubygems'
require 'ap4r'

module Ap4r
  module Script
    class QueueManagerControl < Base
      def start argv, options = {}
        ARGV.unshift('manager', 'start')
        run_rm_client
      end

      def stop argv, options = {}
        ARGV.unshift('manager', 'stop')
        run_rm_client
      end

      private
      def run_rm_client
        ReliableMsg::CLI.new.run
      end
    end
  end
end
