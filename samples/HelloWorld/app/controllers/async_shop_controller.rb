class AsyncShopController < ApplicationController

  def order
    ap4r.transaction do
      do_order
    end

    render :text => 'Order completed successfully.'
  end

  def order_with_saf
    ap4r.transaction do
      do_order
      raise "dummy exception to verify whethrer SAF works well" if params[:raise]
    end

    render :text => 'Order completed successfully.'
  end

  def account
    sleep rand(params[:sleep_time].to_i)

    render :text => 'true'
  end

  private
  def do_order
    Order.create(:item => params[:item] || "Introduction to AP4R")
    ap4r.async_to({:action => 'account'},
                  {:sleep_time => params[id] || 1})
  end


end
