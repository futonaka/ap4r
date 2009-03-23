require 'drb/drb'

class Ap4rClass
  attr_reader :name, :uri, :remote

  def initialize name, uri
    @name = name
    @uri = uri
    @remote = DRb::DRbObject.new_with_uri(uri)
  end

end
