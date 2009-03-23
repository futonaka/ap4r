require File.join(File.dirname(__FILE__), "../spec_helper")

require "reliable-msg"
require "ap4r/mongrel"

describe Ap4r::Mongrel::Ap4rSendMessageHandler, " on accepting a simple message" do

  def start_queue_manager
    @manager = ::ReliableMsg::QueueManager.new(:config => "config/queues_disk.cfg")
    @manager.start_original
  end

  before(:each) do
    start_queue_manager
    q = ::ReliableMsg::Queue.new "queue.test"
    while q.get; end

    params = {
      Mongrel::Const::PATH_INFO => "/queue.test",
      Mongrel::Const::REQUEST_METHOD => "POST",
    }
    class << params
      def http_body
        "hoge"
      end
    end

    class MockSocket
      def initialize;end
      def closed?;false;end
    end

    @handler = Ap4r::Mongrel::Ap4rSendMessageHandler.new(nil)
    @request = Mongrel::HttpRequest.new(params, nil, nil)
    @response = Mongrel::HttpResponse.new(MockSocket.new)
    @handler.process(@request, @response)
  end

  after(:each)do
    @manager.stop_original
  end

  it "should have one message in the queue" do
    q = ReliableMsg::Queue.new "queue.test"
    q.get.should_not be_nil
    q.get.should be_nil
  end

  it "should have the same message body as http body" do
    q = ReliableMsg::Queue.new "queue.test"
    q.get.object.should == "hoge"
  end
end

describe Ap4r::Mongrel::Ap4rSendMessageHandler, " on accepting a message with options" do

  before(:each) do
    @manager = ::ReliableMsg::QueueManager.new(:config => "config/queues_disk.cfg")
    @manager.start_original

    params = {
      Mongrel::Const::PATH_INFO => "/queue.test",
      Mongrel::Const::REQUEST_METHOD => "POST",
      "HTTP_X_AP4R" => "priority=1, delivery=once, dispatch_mode=HTTP, target_method=POST, " +
                       "target_url=http://sample.com:3000"
    }
    class << params
      def http_body
        "hoge"
      end
    end

    class MockSocket
      def initialize;end
      def closed?;false;end
    end

    @handler = Ap4r::Mongrel::Ap4rSendMessageHandler.new(nil)
    @request = Mongrel::HttpRequest.new(params, nil, nil)
    @response = Mongrel::HttpResponse.new(MockSocket.new)
    @handler.process(@request, @response)
  end

  after(:each)do
    @manager.stop_original
  end

  it "should have one message in the queue" do
    q = ReliableMsg::Queue.new "queue.test"
    q.get.should_not be_nil
    q.get.should be_nil
  end

  it "should have the same message body as http body" do
    q = ReliableMsg::Queue.new "queue.test"
    q.get.object.should == "hoge"
  end

  it "should have the same message header as http header" do
    q = ReliableMsg::Queue.new "queue.test"
    m = q.get
    m.headers[:priority].should == 1
    m.headers[:delivery].should == :once
    m.headers[:dispatch_mode].should == :HTTP
    m.headers[:target_method].should == :POST
    m.headers[:target_url].should == "http://sample.com:3000"
  end

end
