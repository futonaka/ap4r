# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

$:.unshift(File.join(File.dirname(__FILE__), '../../'))

require 'logger'
begin
  require 'active_support'
rescue LoadError
  require 'rubygems'
  require 'active_support'
end

require 'ap4r/script/base'
Ap4r::Script::Base.logger = Logger.new(STDOUT)
Ap4r::Script::Base.ap4r_base = File.join(File.dirname(__FILE__) , '../../../')
