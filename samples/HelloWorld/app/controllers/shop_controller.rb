class ShopController < ApplicationController

  def order
    # 注文処理
    # ...

    # 会計処理 (ちょっと重めの処理のイメージ)
    account params[:weight]
  end

  def account sleep_time
    sleep rand(sleep_time)

    render :text => 'Order completed successfully.'
  end

end
