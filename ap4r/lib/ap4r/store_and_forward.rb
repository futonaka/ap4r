# Author:: Kiwamu Kato
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

begin require 'rubygems'; rescue LoadError; end

require 'reliable-msg'
require 'ap4r/stored_message'

module Ap4r

  # This +StoreAndForward+ provides at-least-once QoS level which 
  # guarantees not to lose any message.
  #
  # Example:
  #   
  #   include StoreAndFoward
  #
  #   name = "queue.test.sample"
  #   message = "hogehoge"
  #   options = {}
  #
  #   sm = StoreMessages.store(name, message, options)
  #   forward_by_queue_info(sm.id, {:queue_name => name, 
  #    :queue_message => message, :queue_headers => options})
  #
  module StoreAndForward
    # TODO: make AsyncController include this module. 2007/05/02 by shino

    # TODO: constant or class variable, whick is better? 2007/05/02 by shino
    DRUBY_HOST = ENV['AP4R_DRUBY_HOST'] || 'localhost'
    DRUBY_PORT = ENV['AP4R_DRUBY_PORT'] || '6438'
    DRUBY_URI = "druby://#{DRUBY_HOST}:#{DRUBY_PORT}" 

    # This method needs information about stored message, such as 
    # putting queue's name, message, options, as aruments.
    # And those values stucked queue_info hash and following keys are necessary.
    # * :queue_name
    # * :queue_message
    # * :queue_headers
    #
    # As :queue_headers, some options are supported.
    # See the reliable-msg docuememt for more details.
    #
    # And this method's options is now :delete_mode only. 
    # See the StoreMessage rdoc for more details.
    #
    def __ap4r_forward_by_queue_info(stored_message_id, queue_info, options)
      __ap4r_queue_put(queue_info[:queue_name], queue_info[:queue_message], queue_info[:queue_headers])
      StoredMessage.destroy_if_exists(stored_message_id, options)
    end
    alias :forward_by_queue_info :__ap4r_forward_by_queue_info


    # This method does't need information about stored message.
    # All that is required is stored_message_id.
    # Find target record by stored_message_id, make queue information, such as
    # queue name, message, options, for putting into queue.
    # Now under implementation.
    #
    # And this method's options is now :delete_mode only. 
    # See the StoreMessage rdoc for more details.
    #
    def __ap4r_forward_by_stored_message_id(stored_message_id, options)
      raise "not implemented"
      # TODO: Find record and make queue info , 2006/10/13 kato-k
      queue_name = nil
      queue_message = nil
      queue_headers = nil
      __ap4r_forward_by_queue_info(queue_name, queue_message, queue_headers)
    end
    alias :forward_by_stored_message_id :__ap4r_forward_by_stored_message_id 

    
    # Puts a message into queue.
    # As queue_headers, some options are supported.
    # See the reliable-msg docuememt for more details.
    def __ap4r_queue_put(queue_name, queue_message, queue_headers)
      q = ReliableMsg::Queue.new(queue_name, :drb_uri => @@drb_uri || DRUBY_URI)
      q.put(queue_message, queue_headers)
    end
    alias :queue_put :__ap4r_queue_put

  end
end

#--
# For test
if __FILE__ == $0

  class TestSaf #:nodoc:

    include ::Ap4r::StoreAndForward

    def connect
      unless ActiveRecord::Base.connected?
        #TODO: Get parameters from config, 2006/10/12 kato-k
        ActiveRecord::Base.establish_connection(
                                                :adapter => 'sqlite3',
                                                :database => '../../samples/HelloWorld/db/hello_world_development.db'
                                                )
      end
    end

    def async_dispatch_with_saf(queue_name, queue_message, rm_options = {})

      connect()
      stored_message_id = ::Ap4r::StoredMessage.store(queue_name, queue_message, rm_options)
      forward_by_queue_info(
             stored_message_id, 
             {
               :queue_name => queue_name, 
               :queue_message => queue_message, 
               :queue_headers => rm_options
             }, 
             options = {} )   
    end
  end

  queue_message = "Hello World !"
  queue_name = "queue.test.sample"
  rm_options = {
    :drb_uri=>"druby://localhost:6437",
    :priority => 0,
    :delivery => :repeated
  }

  TestSaf.new.async_dispatch_with_saf(queue_name, queue_message, rm_options)

end
