$:.unshift(File.join(File.dirname(__FILE__), "..", "lib"))

# TODO: stub logic to take files with no specs in coverage report 2007/05/22 by shino
%w(carrier message_store_ext multi_queue
   queue_manager_ext store_and_forward).each{|f|
  require "ap4r/#{f}"
}
