class Ap4rGroup
  include Enumerable

  attr_reader :name, :servers

  def initialize name
    @name = name
    @servers = {}
  end

  Default = Ap4rGroup.new('default')
  GROUPS = {:default => Default}

  def each
    for name in @servers.keys
      yield name, @servers[name].remote
    end
  end

  def add ap4r_name, uri, key = :default
    @servers[ap4r_name] = Ap4rClass.new(ap4r_name, uri)
  end

  def [](name)
    @servers[name].remote if @servers[name]
  end

  def self.get key = :default
    GROUPS[key]
  end

  # configuration stub below here
  default = self.get()
  8.upto(8) do |index|
    default.add("ap4r:643#{index}", "druby://localhost:643#{index}")
  end

end
