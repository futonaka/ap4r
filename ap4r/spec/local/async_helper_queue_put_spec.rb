require File.join(File.dirname(__FILE__), "../spec_helper")

require "reliable-msg"
require "ap4r/async_helper"

module Ap4r::AsyncHelper::Base
  module_function :__queue_put, :__queue_get
end

# ReliableMsg::Queue's mock
class ReliableMsgQueueMock
  def initialize(queue_name, druby_uri)
    @druby_uri = druby_uri
  end

  def put(queue_message, queue_headers)
    case @@ap4r_servers_status[@druby_uri]
    when :active   then "cd6f82d0-e9f1-012b-6ff8-0016cb9ad524" # uuid
    when :inactive then raise ::DRb::DRbConnError
    end
  end

  require "active_support"
  cattr_accessor :ap4r_servers_status
end

class Target
  include Ap4r::AsyncHelper::Base
  def initialize
    @@logger = Logger.new(STDOUT)
    @@logger.level = Logger::INFO
  end

  def queue_put
    __queue_put("", { }, { })
  end

  def __queue_get(queue_name, druby_uri)
    ReliableMsgQueueMock.new(queue_name, druby_uri)
  end

  require "active_support"
  cattr_accessor :logger, :druby_uris, :druby_uri_retry_count
end



describe Ap4r::AsyncHelper::Base, "no configuration and active server" do

  before(:each) do
    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :active
    }
    @target = Target.new
  end

  it "should have default druby uri" do
    @target.druby_uris.size.should == 1
    @target.druby_uris.first.should == "druby://localhost:6438"
  end

  it "should be not error" do
    proc{ @target.queue_put }.should_not raise_error
  end
end


describe Ap4r::AsyncHelper::Base, "no configuration and inactive server" do

  before(:each) do
    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :inactive
    }
    @target = Target.new
  end

  it "should be not error" do
    proc{ @target.queue_put }.should raise_error(::DRb::DRbConnError)
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with default options and active server" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :active,
      "druby://localhost:6439" => :active,
      "druby://localhost:6440" => :active
    }

    @target = Target.new
  end

  it "should have configured URIs list druby uri" do
    @target.druby_uris.size.should == @uris.size
    @target.druby_uris.should == @uris
  end

  it "should be not error" do
    proc{ @target.queue_put }.should_not raise_error
    @target.druby_uris.first.should == @uris.first
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with default options and inactive server" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :inactive,
      "druby://localhost:6439" => :active,
      "druby://localhost:6440" => :active
    }

    @target = Target.new
  end

  it "should be error (should not fail over)" do
    @target.druby_uris.first.should == @uris.first
    proc{ @target.queue_put }.should raise_error(::DRb::DRbConnError)
    @target.druby_uris.first.should == @uris.first
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with rotate option and active server" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris, :rotate => true, :fail_over => false, :fail_reuse => false)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :active,
      "druby://localhost:6439" => :active,
      "druby://localhost:6440" => :active
    }

    @target = Target.new
  end

  it "should rotate servers each connection" do
    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[1]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[2]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should_not raise_error
  end

  it "should have the same URIs list after connections" do
    2.times{ @target.queue_put }
    @target.druby_uris.size.should == 3
    (@target.druby_uris - @uris).should == []
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with rotate option and inactive 2nd server" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris, :rotate => true, :fail_over => false, :fail_reuse => false)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :active,
      "druby://localhost:6439" => :inactive,
      "druby://localhost:6440" => :active
    }

    @target = Target.new
  end

  it "should be error on the 2nd connection" do
    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[1]
    proc{ @target.queue_put }.should raise_error(::DRb::DRbConnError)

    @target.druby_uris.first.should == @uris[1]
  end

  it "should be always error once error occured" do
    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[1]
    proc{ @target.queue_put }.should raise_error(::DRb::DRbConnError)

    @target.druby_uris.first.should == @uris[1]
    proc{ @target.queue_put }.should raise_error(::DRb::DRbConnError)
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with failover option and inactive 1st server" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris, :rotate => false, :fail_over => true, :fail_reuse => false)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :inactive,
      "druby://localhost:6439" => :active,
      "druby://localhost:6440" => :active
    }

    @target = Target.new
  end

  it "should fail over to 2nd server" do
    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[1]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[1]
    @target.druby_uris.size.should == 2
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with failover option and inactive 1st & 2nd servers" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris, :rotate => false, :fail_over => true, :fail_reuse => false)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :inactive,
      "druby://localhost:6439" => :inactive,
      "druby://localhost:6440" => :active
    }

    @target = Target.new
  end

  it "should fail over to 3rd server" do
    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[2]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[2]
    @target.druby_uris.size.should == 1
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with failover option and all inactive servers" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris, :rotate => false, :fail_over => true, :fail_reuse => false)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :inactive,
      "druby://localhost:6439" => :inactive,
      "druby://localhost:6440" => :inactive
    }

    @target = Target.new
  end

  it "should be error" do
    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should raise_error(::RuntimeError, "No more active druby uri.")

    @target.druby_uris.size.should == 0
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with fail_reuse option and inactive 1st server" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris, :rotate => false, :fail_over => true, :fail_reuse => true)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :inactive,
      "druby://localhost:6439" => :active,
      "druby://localhost:6440" => :active
    }

    @target = Target.new
  end

  it "should have the same URIs list after fail over" do
    @target.druby_uri_retry_count.should == 0
    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should_not raise_error
    @target.druby_uri_retry_count.should == 0
    @target.druby_uris.first.should == @uris[1]

    @target.druby_uris.size.should == @uris.size
    (@target.druby_uris - @uris).should == []
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with fail_reuse option and all inactive servers" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris, :rotate => false, :fail_over => true, :fail_reuse => true)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :inactive,
      "druby://localhost:6439" => :inactive,
      "druby://localhost:6440" => :inactive
    }

    @target = Target.new
  end

  it "should be error after tryed all druby uri" do
    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should raise_error(::RuntimeError)

    @target.druby_uris.first.should == @uris[0]
    @target.druby_uris.size.should == @uris.size
    (@target.druby_uris - @uris).should == []
  end

  it "should be not error after some node comes back" do
    proc{ @target.queue_put }.should raise_error(::RuntimeError)

    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :inactive,
      "druby://localhost:6439" => :active,
      "druby://localhost:6440" => :inactive
    }

    @target.druby_uris.first.should == @uris[0]
    proc{ @target.queue_put }.should_not raise_error

    @target.druby_uris.first.should == @uris[1]
  end
end


describe Ap4r::AsyncHelper::Base, "multiple URIs with all options and inactive 2nd server" do

  before(:each) do
    # configuration
    @uris = %w(6438 6439 6440).map {|port| "druby://localhost:#{port}"}
    ::Ap4r::AsyncHelper::Base.druby_uris(@uris, :rotate => true, :fail_over => true, :fail_reuse => true)

    # status
    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :active,
      "druby://localhost:6439" => :inactive,
      "druby://localhost:6440" => :active
    }

    @target = Target.new
  end

  it "should be not error on the first connection" do
    proc { @target.queue_put }.should_not raise_error
  end

  it "should fail over on the second connection" do
    @target.druby_uris.first.should == @uris[0]
    @target.queue_put # connected to 6438

    @target.druby_uris.first.should == @uris[1]
    @target.queue_put # connected to 6440 and rotate next uri

    @target.druby_uris.first.should == @uris[0]
  end

  it "should reuse the uri which it was inactive after it comes back" do
    2.times { @target.queue_put }
    @target.druby_uris.first.should == @uris[0]

    ReliableMsgQueueMock.ap4r_servers_status = {
      "druby://localhost:6438" => :active,
      "druby://localhost:6439" => :active,
      "druby://localhost:6440" => :active
    }

    @target.queue_put # connected to 6438
    @target.queue_put # connected to 6439

    @target.druby_uris.first.should == @uris[2]
  end
end
