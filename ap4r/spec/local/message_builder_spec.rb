require File.join(File.dirname(__FILE__), "../spec_helper")
require 'ap4r/message_builder'
# TODO: move message_builder.rb to lib directory below. 2008/01/18 kiwamu
# require File.join(File.dirname(__FILE__), "../../rails_plugin/ap4r/lib/message_builder")

describe "When simple API is used," do

  describe Ap4r::MessageBuilder, " with an empty message" do
    before(:all) do
      empty_message = {}
      @message_builder = Ap4r::MessageBuilder.new("queue_name", empty_message, {})
    end

    it "should have the right MIME header." do
      pending("TODO: should modify implementation? 2008/01/18 kiwamu")
      mime_type = @message_builder.message_headers["http_header_Content-type".to_sym]
      mime_type.should == "application/x-www-form-urlencoded"
    end

    it "should have the given message." do
      @message_builder.message_body.should == {}
    end

    it "should return also a empty string body after format." do
      @message_builder.format_message_body.should == ""
    end

  end

  describe Ap4r::MessageBuilder, " with a simple message" do
    before(:all) do
      message = {:foo => "bar"}
      @message_builder = Ap4r::MessageBuilder.new("queue_name", message, {})
    end

    it "should have the right MIME header." do
      pending("TODO: should modify implementation? 2008/01/18 kiwamu")
      mime_type = @message_builder.message_headers["http_header_Content-type".to_sym]
      mime_type.should == "application/x-www-form-urlencoded"
    end

    it "should have the given message." do
      @message_builder.message_body.should == {:foo => "bar"}
    end

    it "should return the urlencoded body." do
      @message_builder.format_message_body.should == "foo=bar"
    end

  end

  describe Ap4r::MessageBuilder, " with a nested complicated message" do
    before(:all) do
      @message = {:a => {:b => "c", :d => { :e => "f", :g => "h"}}, :i => "j"}
      @message_builder = Ap4r::MessageBuilder.new("queue_name", @message, {})
    end

    it "should have the given message." do
      @message_builder.message_body.should == @message
    end

    it "should return the urlencoded body." do
      query = @message_builder.format_message_body
      query.split("&").sort.should == %w(a[b]=c a[d][e]=f a[d][g]=h i=j).sort
    end

  end

end


describe "When block style API is used, " do

  describe Ap4r::MessageBuilder, " assigned unknown format" do

    before(:all) do

      block = Proc.new do
        body :key1, "value"
        body :key2, 1
        format :unknown_format
      end

      @message_builder = Ap4r::MessageBuilder.new("", {}, {})
      @message_builder.instance_eval(&block)
    end

    it "should have the right MIME header." do
      pending("TODO: should modify implementation? 2008/01/24 kiwamu")
      mime_type = @message_builder.message_headers["http_header_Content-type".to_sym]
      mime_type.should == "application/x-www-form-urlencoded"
    end

    it "should have the given message." do
      @message_builder.message_body.should == {:key1 => "value", :key2 => 1}
    end

    it "should return the urlencoded body." do
      @message_builder.format_message_body.split("&").sort.should == ["key2=1","key1=value"].sort
    end

  end

  describe Ap4r::MessageBuilder, " assigned text format" do

    before(:all) do

      block = Proc.new do
        body :key1, "value"
        body :key2, 1
        format :text
      end

      @message_builder = Ap4r::MessageBuilder.new("", {}, {})
      @message_builder.instance_eval(&block)
    end

    it "should have the right MIME header." do
      mime_type = @message_builder.message_headers["http_header_Content-type".to_sym]
      mime_type.should == "text/plain"
    end

    it "should return the to_s formatted body." do
      @message_builder.format_message_body.should == {:key1 => "value", :key2 => 1}.to_s
    end
  end

  describe Ap4r::MessageBuilder, " assigned xml format" do

    before(:all) do

      block = Proc.new do
        body :key1, "value"
        body :key2, 1
        format :xml
      end

      @message_builder = Ap4r::MessageBuilder.new("", {}, {})
      @message_builder.instance_eval(&block)
    end

    it "should have the right MIME header." do
      mime_type = @message_builder.message_headers["http_header_Content-type".to_sym]
      mime_type.should == "application/xml"
    end

    it "should return the xml formatted body." do
      @message_builder.format_message_body.should == {:key1 => "value", :key2 => 1}.to_xml(:root => "root")
    end
  end

  describe Ap4r::MessageBuilder, " assigned json format" do

    before(:all) do

      block = Proc.new do
        body :key1, "value"
        body :key2, 1
        format :json
      end

      @message_builder = Ap4r::MessageBuilder.new("", {}, {})
      @message_builder.instance_eval(&block)
    end

    it "should have the right MIME header." do
      mime_type = @message_builder.message_headers["http_header_Content-type".to_sym]
      mime_type.should == "application/json"
    end

    it "should return the json formatted body." do
      @message_builder.format_message_body.should == {:key1 => "value", :key2 => 1}.to_json
    end
  end

  describe Ap4r::MessageBuilder, " assigned yaml format" do

    before(:all) do

      block = Proc.new do
        body :key1, "value"
        body :key2, 1
        format :yaml
      end

      @message_builder = Ap4r::MessageBuilder.new("", {}, {})
      @message_builder.instance_eval(&block)
    end

    it "should have the right MIME header." do
      mime_type = @message_builder.message_headers["http_header_Content-type".to_sym]
      mime_type.should == "text/yaml"
    end

    it "should return the yaml formatted body." do
      @message_builder.format_message_body.should == {:key1 => "value", :key2 => 1}.to_yaml
    end
  end

end
