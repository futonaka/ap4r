class SafController < ApplicationController

  def index
    list
    render :action => 'list'
  end

  # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
  verify :method => :post, :only => [ :destroy, :create, :update, :recovery ],
         :redirect_to => { :action => :list }

  def list
    @stored_message_pages, @stored_messages = paginate :stored_messages, :class_name => '::Ap4r::StoredMessage', :per_page => 10
  end

  def show
    @stored_message = ::Ap4r::StoredMessage.find(params[:id])
  end

  def new
    @stored_message = ::Ap4r::StoredMessage.new
  end

  def create
    @stored_message = ::Ap4r::StoredMessage.new(params[:stored_message])
    if @stored_message.save
      flash[:notice] = 'StoredMessage was successfully created.'
      redirect_to :action => 'list'
    else
      render :action => 'new'
    end
  end

  def edit
    @stored_message = ::Ap4r::StoredMessage.find(params[:id])
  end

  def update
    @stored_message = Ap4r::StoredMessage.find(params[:id])
    if @stored_message.update_attributes(params[:stored_message])
      flash[:notice] = 'StoredMessage was successfully updated.'
      redirect_to :action => 'show', :id => @stored_message
    else
      render :action => 'edit'
    end
  end

  def destroy
    ::Ap4r::StoredMessage.find(params[:id]).destroy
    redirect_to :action => 'list'
  end

  def recovery
    @stored_message = ::Ap4r::StoredMessage.find(params[:id])
    @stored_message.forward_and_update_status

    redirect_to :action => 'list'
  end
end
