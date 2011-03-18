# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'rubygems'
require 'reliable-msg'
require 'ap4r/queue-manager'

hack = true
debug_hack = true

require 'ap4r/version'

if hack
  require "ap4r/queue_manager_ext"
end

if debug_hack
  require "ap4r/queue_manager_ext_debug"
end

