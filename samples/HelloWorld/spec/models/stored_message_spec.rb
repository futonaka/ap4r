require File.dirname(__FILE__) + '/../spec_helper'

describe Ap4r::StoredMessage, "with an exception throwed in transaction block" do

  it "should be rolled back" do
    # TODO: NOT purely the model's example because the Order model is included 2007/11/27 by shino
    lambda {
      Ap4r::StoredMessage.transaction do
        Ap4r::StoredMessage.store("dummy_queue", "dummy_message")
        raise "dummy exception"
      end
    }.should raise_error

    Ap4r::StoredMessage.should have(:no).records
  end

  it "should be rolled back (Order is created in advance)" do
    # TODO: NOT purely the model's example because the Order model is included 2007/11/27 by shino
    lambda {
      Ap4r::StoredMessage.transaction do
        Order.create({ :item => "item name"})
        Ap4r::StoredMessage.store("dummy_queue", "dummy_message")
        raise "dummy exception"
      end
    }.should raise_error

    Ap4r::StoredMessage.should have(:no).records
  end

  it "should be rolled back (Order is created afterwards)" do
    # TODO: NOT purely the model's example because the Order model is included 2007/11/27 by shino
    lambda {
      Ap4r::StoredMessage.transaction do
        Ap4r::StoredMessage.store("dummy_queue", "dummy_message")
        Order.create({ :item => "item name"})
        raise "dummy exception"
      end
    }.should raise_error

    Ap4r::StoredMessage.should have(:no).records
  end

  it "should be rolled back as well as Order (Order is created in advance)" do
    # TODO: NOT purely the model's example because the Order model is included 2007/11/27 by shino
    lambda {
      Ap4r::StoredMessage.transaction do
        Order.create({ :item => "item name"})
        Ap4r::StoredMessage.store("dummy_queue", "dummy_message")
        raise "dummy exception"
      end
    }.should raise_error

    Order.should have(:no).records
  end

  it "should be rolled back as well as Order (Order is created afterward" do
    # TODO: NOT purely the model's example because the Order model is included 2007/11/27 by shino
    lambda {
      Ap4r::StoredMessage.transaction do
        Ap4r::StoredMessage.store("dummy_queue", "dummy_message")
        Order.create({ :item => "item name"})
        raise "dummy exception"
      end
    }.should raise_error

    Order.should have(:no).records
  end

end

describe Ap4r::StoredMessage, "when dumping its headers" do
  it "should not raise Exceptions" do
    lambda {
      s = Ap4r::StoredMessage.new
      s.dumped_headers
    }.should_not raise_error
  end
end

describe Ap4r::StoredMessage, "when dumping its object" do
  it "should not raise Exceptions" do
    lambda {
      s = Ap4r::StoredMessage.new
      s.dumped_object
    }.should_not raise_error
  end
end
