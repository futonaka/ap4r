require File.join(File.dirname(__FILE__), "../spec_helper")

require "reliable-msg"
require "ap4r/recoverer"

describe Ap4r::Recoverers do 

  def start_queue_manager
    @manager = ::ReliableMsg::QueueManager.new(:config => "config/queues_disk.cfg")
    @manager.start_original
  end

  before do
    start_queue_manager
    q = ReliableMsg::Queue.new "$dlq"
    while q.get; end
    @logger = Logger.new(nil)
  end

  context "when start recoverer which initialized without config" do
    before do
      @recov = Ap4r::Recoverers.new(@manager, nil, @logger)
    end

    it "should return nil and not start recoverer_loop." do
      @logger.should_not_receive(:warn)
      @logger.should_not_receive(:error)

      @recov.start.should be_nil
      @recov.instance_variable_get(:@group).list.should be_empty
    end
  end

  context "when initialized with all arguments" do
    context "and start" do
      before do
        config = [
          {
            "threads"    => 1,
            "every"      => 1.0,
            "count"      => 10,
            "on_expired" => nil,
          }
        ]
        @recov = Ap4r::Recoverers.new(@manager, config, @logger)
      end

      it "should start recoverer_loop" do
        @logger.should_not_receive(:warn)
        @logger.should_not_receive(:error)
        @recov.start.should_not be_nil
        @recov.instance_variable_get(:@group).list.should_not be_empty 
      end
    end

    context "and 2 messages in DLQ, one is already tried :max_delivery_times" do
      context "if on_expired = nil" do
        before do
          config = [
            {
              "threads"    => 1,
              "every"      => 1.0,
              "count"      => 10,
              "on_expired" => nil,
            }
          ]
          @recov = Ap4r::Recoverers.new(@manager, config, @logger)
          @recov.start

          q = ReliableMsg::Queue.new "$dlq"
          q.put "hoge", {:queue => "$dlq", :redelivery => 5}
          q.put "fuga", {:queue => "$dlq", :redelivery => 1}
        end

        it "should delete max times delivered messages from DLQ." do
          @logger.should_not_receive(:warn)
          @logger.should_not_receive(:error)

          @manager.list(:queue => "$dlq").should have(2).items
          sleep 1
          @manager.list(:queue => "$dlq").should have(1).item
        end
      end

      context "if on_expired = \"Proc.new{ |m| dlq.put(m.object, m.headers)}\"" do
        before do
          config = [
            {
              "threads"    => 1,
              "every"      => 1.0,
              "count"      => 10,
              "on_expired" => "Proc.new{ |m| dlq.put(m.object, m.headers)}",
            }
          ]
          @recov = Ap4r::Recoverers.new(@manager, config, @logger)
          @recov.start

          q = ReliableMsg::Queue.new "$dlq"
          q.put "hoge", {:queue => "$dlq", :redelivery => 5}
          q.put "fuga", {:queue => "$dlq", :redelivery => 1}
        end

        it "should put max times delivered massages to DLQ again." do
          @logger.should_not_receive(:warn)
          @logger.should_not_receive(:error)

          @manager.list(:queue => "$dlq").should have(2).items
          sleep 1
          @manager.list(:queue => "$dlq").should have(2).items
        end
      end
    end
  end

  after do
    @recov.stop
    @manager.stop_original
  end
end
