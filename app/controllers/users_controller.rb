class UsersController < ApplicationController
  before_action :set_user, only: [:show, :edit, :update, :destroy]

  # GET /users
  def index
    @users = User.all
  end

  # GET /users/1
  def show
    @changes = PaperTrail::Version.where(whodunnit: @user.id).
               order(created_at: :desc).
               page(params[:changes_page])
    around_now = Time.zone.now-7.days..Time.zone.now+7.days
    @sessions = ResearchSession.includes(:user).
                where(start_datetime: around_now, user_id: @user.id).
                page(params[:sessions_page])
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit; end

  # POST /users
  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to @user, notice: 'User was successfully created.'
    else
      render :new
    end
  end

  # PATCH/PUT /users/1
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to(@user, notice: 'User was successfully updated.') }
        format.json { respond_with_bip(@user) }
      else
        format.html { render :edit }
        format.json { respond_with_bip(@user) }
      end
    end
  end

  # DELETE /users/1
  def destroy
    @user.destroy
    redirect_to users_url, notice: 'User was successfully destroyed.'
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def user_params
      params.require(:user).permit(:name,
                                   :approved,
                                   :phone_number,
                                   :email_address)
    end

end