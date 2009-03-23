Ap4r::Configuration.setup {|services|
  services.add 'queues_disk.cfg', :host => 'localhost', :name => :rm1
#  services.add 'queues.cfg', :name => :rm2
}

