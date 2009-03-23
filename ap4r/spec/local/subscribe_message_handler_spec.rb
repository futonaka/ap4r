require File.join(File.dirname(__FILE__), "../spec_helper")

require "reliable-msg"
require "ap4r/mongrel"

describe Ap4r::Mongrel::Ap4rSubscribeMessageHandler, " on subscribing a simple message" do

  def start_queue_manager
    @manager = ::ReliableMsg::QueueManager.new(:config => "config/queues_disk.cfg")
    @manager.start_original
  end

  before(:each) do
    start_queue_manager

    q = ::ReliableMsg::Queue.new "queue.test"
    while q.get; end
    q.put "hgoe"

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

    @handler = Ap4r::Mongrel::Ap4rSubscribeMessageHandler.new(nil)
    @request = Mongrel::HttpRequest.new(params, nil, nil)
    @response = Mongrel::HttpResponse.new(MockSocket.new)
    @handler.process(@request, @response)
  end

  after(:each)do
    @manager.stop_original
  end

  it "should have no message in the queue" do
    q = ReliableMsg::Queue.new "queue.test"
    q.get.should be_nil
  end

end

