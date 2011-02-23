require File.join(File.dirname(__FILE__), "../spec_helper")

require "reliable-msg"
require "ap4r/balancer"

describe Ap4r::Balancer do 
  before do
    @logger = Logger.new(STDOUT)
  end

  context "when initialized without config" do
    before do
      @balancer = Ap4r::Balancer.new(nil, @logger)
    end

    it "should be initialized." do
      @balancer.should be_kind_of(Ap4r::Balancer)
    end

    it "#start, #stop should not raise error." do
      Proc.new {
        @balancer.start
        @balancer.stop
      }.should_not raise_error(RuntimeError)
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

  context "when initialized with config" do
    before do
      balancer_config = { "targets" => 
        [{:host => "localhost", :port => 3000}, "localhost:4000"] 
      }
      TCPSocket.stub!(:open).and_return(true)
      @balancer = Ap4r::Balancer.new(balancer_config, @logger)
    end
    
    it "should be initialized." do
      @balancer.should be_kind_of(Ap4r::Balancer)
      @balancer.instance_variable_get(:@monitors).should have(2).items
      monitor = []
      @balancer.instance_variable_get(:@monitors).each{ |m|
        monitor << m
      }
      monitor[0].should be_kind_of(Ap4r::Balancer::TargetMonitor)
      monitor[1].should be_kind_of(Ap4r::Balancer::TargetMonitor)
    end

    it "should be able to start." do
      @balancer.start
    end

    it "should be able to start and stop, start..." do
      Proc.new {
        @balancer.start
        @balancer.stop
      }.should_not raise_error(RuntimeError)
    end

    context "and started" do
      before do
        @balancer.start
      end

      it "should be able to stop." do
        Proc.new { 
          @balancer.stop
        }.should_not raise_error(RuntimeError)
      end

      it "should be set #get_with_config to #get" do
        h, p = nil, nil

        @balancer.get{ |host, port|
          h = host
          p = port
        }

        h.should_not be_nil
        p.should_not be_nil
      end

      after do
        @balancer.stop
      end
    end

    after do
      @balancer.stop rescue nil
    end
  end

  after do
    @balancer = nil
    @logger = nil
  end
end
