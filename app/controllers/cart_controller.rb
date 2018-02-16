# frozen_string_literal: true

class CartController < ApplicationController
  include ApplicationHelper
  before_action :cart_init, except: :change_cart

  # Index
  def show
    @people = @cart.people
    @users = @cart.users
    @comment = Comment.new commentable: @cart
    @selectable_users = User.approved.where.not(id: @users.map(&:id))
    respond_to do |format|
      format.html
      format.json { render json: @people.map(&:id) }
    end
  end

  def new
    @cart = Cart.new
  end

  def create
    @cart = Cart.new(cart_params)
    @cart.user_id = current_user.id
    @cart.users << current_user
    @create_result = @cart.save
    respond_to do |format|
      if @create_result
        format.js {}
        format.json {}
        format.html { redirect_to @cart, notice: 'Pool was successfully created.'  }
      else
        format.js {}
        format.html { render action: 'new' }
        format.json { render json: @cart.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @cart.update(cart_update_params)
        format.html { redirect_to cart_path(@cart), notice: 'Gift card was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @cart.errors, status: :unprocessable_entity }
      end
    end
  end

  # rubocop:disable Metrics/MethodLength
  def add
    people = Person.where(id: cart_params[:person_id])
    @added = []
    people.each do |person|
      @added << person.id unless @cart.people.include? person
      @cart.people << person
    end
    @cart.save
    respond_to do |format|
      format.js
      format.json { render json: @cart.people.map(&:id) }
      format.html { render json: @cart.people.map(&:id) }
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Delete
  # rubocop:disable Metrics/MethodLength
  def delete
    if cart_params[:person_id].blank?
      @deleted = @cart.people.map(&:id)
      @cart.people = []
    else
      @deleted = [cart_params[:person_id]]
      person = Person.find(cart_params[:person_id])
      @cart.people.delete(person) if person.present?
    end
    @cart.save

    respond_to do |format|
      format.js
      format.json { render json: @cart.to_json }
      format.html { render json: @cart.to_json }
    end
  end
  # rubocop:enable Metrics/MethodLength


  def index
    current_user.reload
    @carts = Cart.includes(:users).all

    respond_to do |format|
      # format.js
      format.json { render json: @carts.to_json }
      format.html
    end
  end

  
  # DELETE /gift_cards/1
  # DELETE /gift_cards/1.json
  def destroy
    @cart.destroy
    flash[:notice] = "#{@cart.name} has been destroyed"
    respond_to do |format|
      format.html { redirect_to :back }
      format.json { head :no_content }
      format.js {}
    end
  end
  

  def change_cart
    @cart = Cart.find(params[:cart]) || current_cart
    current_user.current_cart = @cart
    respond_to do |format|
      format.html { redirect_to cart_path(@cart)}
      format.json do
        render json: { success: true,
                       cart_id: @cart.id,
                       cart_name: cart_name }
      end
      format.js {render layout: false}
    end
  end

  def check_name
    @cart_name_valid = !Cart.where(name: param[:name]).exists?
    status = @cart_name_valid ? 200 : 422
    respond_to do |format|
      format.json do
        render json: { success: @cart_name_valid, valid: @cart_name_valid }, status: status
      end
      format.html render text: @cart_name_valid , status: status
    end
  end

  def add_user
    @user = User.find(cart_params[:user_id])
    @cart.users << @user
    flash[:notice] = "#{@user.name} has been added to the cart"
  end

  def delete_user
    @deleted = nil
    @user = User.find(cart_params[:user_id])
    if @cart.users.size >= 1 && @cart.users.include?(@user)
      @deleted = @cart.users.delete(@user)
      @cart.save
    end

    if @deleted.nil?
      flash[:error] = "Can't remove user..."
    else
      flash[:notice] = "#{@user.name} has been removed"
    end
  end

  private

    def cart_update_params
      params.require(:cart).permit(:description,
                                   :name,
                                   :id,
                                   :user_id,
                                   :user,
                                   :person,
                                   :person_id)
    end

    def cart_params
      params.permit(:person_id,
                    :all,
                    :type,
                    :name,
                    :id,
                    :user,
                    :user_id,
                    :description,
                    :notes)
    end

    def cart_init
      @type = cart_params[:type].presence || 'full'
      if cart_params[:id].present?
        @cart = Cart.find(cart_params[:id])
        current_user.current_cart = @cart
      else  
        @cart ||= current_user.current_cart
      end

    end
end
