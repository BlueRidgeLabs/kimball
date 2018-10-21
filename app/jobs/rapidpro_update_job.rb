# frozen_string_literal: true

class RapidproUpdateJob
  include Sidekiq::Worker
  sidekiq_options retry: 5

  # works like so, if person has no rapidpro uuid, we post with phone,
  # otherwise use uuid. this will allow changes to phone numbers.
  # additionally, it means we only need one worker.
  def initialize
    @headers = { 'Authorization' => "Token #{ENV['RAPIDPRO_TOKEN']}",
               'Content-Type'  => 'application/json' }
    @base_url = 'https://rapidpro.brl.nyc/api/v2/'
  end

  def perform(id)
    Rails.logger.info '[RapidProUpdate] job enqueued'
    person = Person.find(id)
    # we may deal with a word where rapidpro does email...
    # but not now.
    if person.phone_number.present?
      endpoint_url = @base_url + 'contacts.json'

      lang = case person.locale
             when 'en'
               'eng'
             when 'es'
               'spa'
             when 'zh'
               'chi'
             else
               'eng'
              end

      body = { name: person.full_name,
               first_name: person.first_name,
               language: lang }
      # eventual fields: # first_name: person.first_name,
      # last_name: person.last_name,
      # email_address: person.email_address,
      # zip_code: person.postal_code,
      # neighborhood: person.neighborhood,
      # patterns_token: person.token,
      # patterns_id: person.id

      urn = "tel:#{person.phone_number}"

      if person&.rapidpro_uuid.present? # already created in rapidpro
        url = endpoint_url + "?uuid=#{person.rapidpro_uuid}"
        body[:urns] = [urn] # adds new phone number if need be.
        body[:urns] << "mailto:#{person.email_address}" if person.email_address.present?
        body[:groups] = ['DIG']
        # rapidpro tags are space delimited and have underscores for spaces
        body[:fields] = { tags: person.tag_list.map { |t| t.tr(' ', '_') }.join(' ') }
      else # person doesn't yet exist in rapidpro
        cgi_urn = CGI.escape(urn)
        url = endpoint_url + "?urn=#{cgi_urn}" # uses phone number to identify.
      end

      res = HTTParty.post(url, headers: @headers, body: body.to_json)

      case res.code
      when 201 # new person in rapidpro
        if person.rapidpro_uuid.blank?
          # update column to skip callbacks
          person.update_column(:rapidpro_uuid, res.parsed_response['uuid'])
        end
      when 429 # throttled
        retry_delay = res.headers['retry-after'].to_i + 5
        RapidproUpdateJob.perform_in(retry_delay, id) # re-queue job
      when 200 # happy response
        return true
      else
        puts res.code
        raise "error: #{res.code}"
      end
    end
  end
end
