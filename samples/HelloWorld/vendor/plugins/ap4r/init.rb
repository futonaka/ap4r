# Author:: Shunichi Shinohara
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

require 'ap4r_client'

class ActionController::Base
  def ap4r
    @ap4r_client ||= ::Ap4r::Client.new(self)
  end
end
