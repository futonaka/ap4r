require File.join(File.dirname(__FILE__), "../spec_helper")

require "reliable-msg"
require "ap4r/dispatcher"

class Ap4r::Dispatchers::Base
  attr_accessor :response
end

describe Ap4r::Dispatchers::Base, " message modification with no configuration" do
  before(:each) do
    @headers = {:target_url => "http://www.sample.org:8888/aaa/bbb" }
    @body = "body"
    @message = ReliableMsg::Message.new(1, @headers.clone, @body.clone)
    @conf = {}
    @dispatcher = Ap4r::Dispatchers::Base.new(@message, @conf)
    @dispatcher.modify_message
  end

  it "should not change headers" do
    @message.headers == @headers.should
  end

  it "should not change body" do
    @message.object.should == @body
  end

end

describe Ap4r::Dispatchers::Base, " message modification with url rewrite" do
  before(:each) do
    @headers = {:target_url => "http://www.sample.org:8888/aaa/bbb" }
    @body = "body"
    @message = ReliableMsg::Message.new(1, @headers.clone, @body.clone)
    @conf = {"modify_rules" => {"url" => "proc{|url| url.port = url.port + 11}" }}
    @dispatcher = Ap4r::Dispatchers::Base.new(@message, @conf)
    @dispatcher.modify_message
  end

  it "should not change headers except :target_url" do
    @message.headers[:target_url] = @headers[:target_url]
    @message.headers.should == @headers
  end

  it "should change :target_url as ruled" do
    @message.headers[:target_url].should == "http://www.sample.org:8899/aaa/bbb"
  end

  it "should not change body" do
    @message.object.should == @body
  end

end

describe Ap4r::Dispatchers::Http, " validation of response status as HTTP OK" do
  before(:each) do
    @dispatcher = Ap4r::Dispatchers::Http.new(@message = nil, @conf = nil)
  end

  it "should accept 200 status" do
    @dispatcher.response = Net::HTTPOK.new(nil, 200, nil)
    proc{ @dispatcher.validate_response_status(Net::HTTPOK) }.should_not raise_error
  end

  it "should repel 201 status" do
    @dispatcher.response = Net::HTTPCreated.new(nil, 201, nil)
    proc{ @dispatcher.validate_response_status(Net::HTTPOK) }.should raise_error
  end

  it "should repel 301 status" do
    @dispatcher.response = Net::HTTPMovedPermanently.new(nil, 301, nil)
    proc{ @dispatcher.validate_response_status(Net::HTTPOK) }.should raise_error
  end

end

describe Ap4r::Dispatchers::Http, " validation of response status as 2xx" do
  before(:each) do
    @dispatcher = Ap4r::Dispatchers::Http.new(@message = nil, @conf = nil)
  end

  it "should accept 200 status" do
    @dispatcher.response = Net::HTTPOK.new(nil, 200, nil)
    proc{ @dispatcher.validate_response_status(Net::HTTPSuccess) }.should_not raise_error
  end

  it "should accept 201 status" do
    @dispatcher.response = Net::HTTPCreated.new(nil, 201, nil)
    proc{ @dispatcher.validate_response_status(Net::HTTPSuccess) }.should_not raise_error
  end

  it "should repel 301 status" do
    @dispatcher.response = Net::HTTPMovedPermanently.new(nil, 301, nil)
    proc{ @dispatcher.validate_response_status(Net::HTTPSuccess) }.should raise_error
  end

end

describe Ap4r::Dispatchers::Http, " validation of response body" do
  before(:each) do
    @message = nil
    @conf = nil
    @dispatcher = Ap4r::Dispatchers::Http.new(@message, @conf)
    @response = mock("response")
    @dispatcher.response = @response
  end

  it 'should accept just text "true"' do
    @response.should_receive(:body).once.and_return("true")
    proc{ @dispatcher.validate_response_body(/true/) }.should_not raise_error
  end

  it 'should accept text including "true"' do
    @response.should_receive(:body).and_return{
      "first line is not important\nsome words true and more\nand also third line is useless." }
    proc{ @dispatcher.validate_response_body(/true/) }.should_not raise_error
  end

  it 'should repel empty text' do
    @response.should_receive(:body).and_return("")
    proc{ @dispatcher.validate_response_body(/true/) }.should raise_error
  end

  it 'should repel long text without "true"' do
    @response.should_receive(:body).and_return{
      "first line is not important\nsome words, more and more\nand also third line is useless." }
    proc{ @dispatcher.validate_response_body(/true/) }.should raise_error
  end

end
