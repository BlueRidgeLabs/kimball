#

class Public::PeopleController < ApplicationController
  layout false
  after_action :allow_iframe
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  # GET /people/new
  def new
    @referrer = false
    if params[:referrer]
      begin
        uri = URI.parse(params[:referrer])
        @referrer = params[:referrer] if uri.is_a?(URI::HTTP)
      rescue URI::InvalidURIError
        @referrer = false
      end
    end
    @person = ::Person.new
  end

  def show
    find_user_or_redirect_to_root
    if @person
      render json: @person.to_json
    else
      render json: { success: false }
    end
  end

  def update
    find_user_or_redirect_to_root
    PaperTrail.whodunnit = @current_user

    phone_number = PhonyRails.normalize_number(update_params[:phone_number])

    @person = Person.find_by(phone_number: phone_number)

    if @person
      if update_params[:tags].present?
        tags = update_params.delete(:tags)
        @person.tag_list.add(tags.split(','))
      end

      if update_params[:note].present?
        comment =  update_params.delete(:note)
        Comment.create(content: comment,
                       user_id: @current_user.id,
                       commentable_type: 'Person',
                       commentable_id: @person.id)
      end

      @person.update_attributes(update_params)
    end
    if @person&.save
      render json: { success: true }
    else
      render json: { success: false }
    end
  end

  # POST /people
  # rubocop:disable Metrics/MethodLength
  def create
    @person = ::Person.new(person_params)
    @person.signup_at = Time.current

    success_msg = 'Thanks! We will be in touch soon!'
    error_msg   = "Oops! Looks like something went wrong. Please get in touch with us at <a href='mailto:#{ENV['MAILER_SENDER']}?subject=Patterns sign up problem'>#{ENV['MAILER_SENDER']}</a> to figure it out!"

    @person.tag_list.add(params[:age_range]) if params[:age_range].present?

    if params[:referral].present?
      @person.referred_by = params[:referral][0, 100] # only 100 characters
    end

    @msg = @person.save ? success_msg : error_msg
    respond_to do |format|
      format.html { render action: 'create' }
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def deactivate
    @person = Person.find_by(token: d_params[:token])

    if @person && @person.id == d_params[:person_id].to_i
      @person.deactivate!('email')
      @person.save
      ::AdminMailer.deactivate(person: @person).deliver_later
    else
      redirect_to root_path
    end
  end

  private

    def update_params
      person_attributes = Person.attribute_names.map(&:to_sym)
      %i[id created_at signup_at updated_at cached_tag_list].each do |del|
        person_attributes.delete_at(person_attributes.index(del))
      end
      person_attributes += %i[phone_number tags note]
      params.permit(person_attributes)
    end

    def d_params
      params.permit(:person_id, :token)
    end

    # rubocop:disable Metrics/MethodLength
    def person_params
      params.require(:person).permit(:first_name,
        :last_name,
        :email_address,
        :phone_number,
        :preferred_contact_method,
        :low_income,
        :address_1,
        :address_2,
        :city,
        :state,
        :postal_code,
        :token,
        :primary_device_id,
        :primary_device_description,
        :secondary_device_id,
        :secondary_device_description,
        :primary_connection_id,
        :primary_connection_description,
        :secondary_connection_id,
        :secondary_connection_description,
        :participation_type,
        :referred_by)
    end
    # rubocop:enable Metrics/MethodLength

    def allow_iframe
      response.headers.except! 'X-Frame-Options'
    end

    def find_user_or_redirect_to_root
      if request.headers['AUTHORIZATION'].present?
        @current_user = User.find_by(token: request.headers['AUTHORIZATION'])

        return redirect_to root_path if update_params[:phone_number].blank?

        phone = PhonyRails.normalize_number(update_params[:phone_number])
        @person = Person.find_by(phone_number: phone)

        return redirect_to root_path if @current_user.nil? || @person.nil?
      else
        return redirect_to root_path
      end
    end
end
