# frozen_string_literal: true

# rubocop:disable ClassLength
class SearchController < ApplicationController

  include PeopleHelper
  include SearchHelper

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength
  def index_ransack
    @tags = SearchService.parse_tags(params[:q])
    params[:q] = SearchService.normalize_query(params[:q])
    # allow for larger pages
    Person.per_page = params[:per_page] if params[:per_page].present?
    @q = current_user.admin? ? Person.ransack(params[:q]) : Person.verified.ransack(params[:q])
    @results = @q.result.distinct(:person).includes(:tags).page(params[:page])

    respond_to do |format|
      format.json { @results }
      format.html
      format.csv do
        if current_user.admin?
          @results = @q.result.includes(:tags)
          fields = Person.column_names
          fields.push('tags')
          output = CSV.generate do |csv|
            # Generate the headers
            csv << fields.map(&:titleize)

            # Some fields need a helper method
            human_devices = %w[primary_device_id secondary_device_id]
            human_connections = %w[primary_connection_id secondary_connection_id]

            # Write the results
            @results.each do |person|
              csv << fields.map do |f|
                field_value = person[f]
                if human_devices.include? f
                  human_device_type_name(field_value)
                elsif human_connections.include? f
                  human_connection_type_name(field_value)
                elsif f == 'phone_number'
                  if field_value.present?
                    field_value.phony_formatted(format: :national, spaces: '-')
                  else
                    ''
                  end
                elsif f == 'tags'
                  if person.tag_values.blank?
                    ''
                  else
                    person.tag_values.join('|')
                  end
                else
                  field_value
                end
              end
            end
          end
          send_data output, filename: "Search-#{Time.zone.today}.csv"
        else
          flash[:error] = 'Not permitted'
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/BlockLength

  # FIXME: Refactor and re-enable cop
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  #
  def export_ransack
    list_name = params.delete(:segment_name)
    @q = Person.ransack(params[:q])
    @results = @q.result.includes(:tags)
    @mce = MailchimpExport.new(name: list_name, recipients: @results.collect(&:email_address), created_by: current_user.id)
    if @mce.with_user(current_user).save
      Rails.logger.info("[SearchController#export] Sent #{@mce.recipients.size} email addresses to a static segment named #{@mce.name}")
      respond_to do |format|
        format.js {}
      end
    else
      Rails.logger.error("[SearchController#export] failed to send event to mailchimp: #{@mce.errors.inspect}")
      format.all { render text: "failed to send event to mailchimp: #{@mce.errors.inspect}", status: :bad_request }
    end
  end

  def export
    # send all results to a new static segment in mailchimp
    list_name = params.delete(:segment_name)
    @q = Person.active.ransack(params[:q])
    @people = @q.result.includes(:tags)
    @mce = MailchimpExport.new(name: list_name, recipients: @people.collect(&:email_address), created_by: current_user.id)

    if @mce.with_user(current_user).save
      Rails.logger.info("[SearchController#export] Sent #{@mce.recipients.size} email addresses to a static segment named #{@mce.name}")
      respond_to do |format|
        format.js {}
      end
    else
      Rails.logger.error("[SearchController#export] failed to send event to mailchimp: #{@mce.errors.inspect}")
      format.all { render text: "failed to send event to mailchimp: #{@mce.errors.inspect}", status: :bad_request }
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def add_to_cart
    @q = Person.active.ransack(params[:q])
    pids = current_cart.people_ids
    new_pids = @q.result.map(&:id).delete_if { |i| pids.include?(i) }
    people = Person.find(new_pids)
    flash[:notice] = "adding #{people.size} to pool"
    current_cart.people << people
    flash[:notice] = "#{new_pids.size} people added to #{current_cart.name}."
    respond_to do |format|
      format.js {}
      format.json { render json: { success: true } }
    end
  end

  def advanced
    @search = ransack_params
    @search.build_grouping unless @search.groupings.exists?
    @people = ransack_result
  end

  private

    def ransack_params
      Person.includes(:tags, :comments).ransack(params[:q])
    end

    def ransack_result
      @search.result(distinct: user_wants_distinct_results?)
    end

    # lotta params...
    # rubocop:disable Metrics/MethodLength,
    def index_params
      params.permit(:q,
                    :adv,
                    :active,
                    :first_name,
                    :last_name,
                    :email_address,
                    :postal_code,
                    :phone_number,
                    :verified,
                    :device_description,
                    :connection_description,
                    :device_id_type,
                    :connection_id_type,
                    :geography_id,
                    :event_id,
                    :address,
                    :city,
                    :tags,
                    :preferred_contact_method,
                    :page)
    end
  # rubocop:enable Metrics/MethodLength
end
# rubocop:enable ClassLength
