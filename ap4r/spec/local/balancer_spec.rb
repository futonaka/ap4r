require File.join(File.dirname(__FILE__), "../spec_helper")

require "reliable-msg"
require "ap4r/balancer"

describe Ap4r::Balancer do 

  before do
    @logger = Logger.new(STDOUT)
  end

  context "when initialized without config" do
    before do
      @balancer = Ap4r::Balancer.new nil, @logger 
    end

    it "should be initialized." do
      @balancer.should be_kind_of Ap4r::Balancer
    end

    it "#start, #stop should not raise error." do
      @balancer.start
      @balancer.stop
    end

    it "#get should yield with nil, and return nil." do
      h = "host", p = "port"

      @balancer.get{ |host, port| 
        h = host
        p = port
      }.should be_nil

      h.should be_nil
      p.should be_nil
    end
  end

  context "when initialized with invalid config" do
    it "should raise error." do
      Proc.new {
        Ap4r::Balancer.new({ "targets" => 123 }, @logger)
      }.should raise_error
    end
  end

  context "when initialized with config" do
    before do
      balancer_config = { "targets" => 
        [{:host => "hogehost", :port => 1234}, "fugahost:5678"] 
      }
      TCPSocket.stub!(:open).and_return true
      @balancer = Ap4r::Balancer.new balancer_config, @logger
    end
    
    it "should be initialized." do
      @balancer.should be_kind_of Ap4r::Balancer
      @balancer.instance_variable_get(:@monitors).should have(2).items
      @balancer.instance_variable_get(:@monitors).each{ |m| 
        m.should be_kind_of Ap4r::Balancer::TargetMonitor
      }
    end

    it "should be able to start and stop" do
      @balancer.start
      @balancer.stop
    end

    context "and started" do
      it "should be set #get_with_config to #get" do
        h, p = nil, nil

        @balancer.start
        @balancer.get{ |host, port|
          h = host
          p = port
        }
        h.should_not be_nil
        p.should_not be_nil
      end
    end

  end

  after do
    @balancer.stop rescue nil
    @balancer = nil
    @logger = nil
  end
end
