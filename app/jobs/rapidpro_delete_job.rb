# frozen_string_literal: true
class RapidproDeleteJob
  include Sidekiq::Worker
  sidekiq_options retry: 5

  def perform(id)
    Rails.logger.info '[RapidProDelete] job enqueued'
    person = Person.find id
    if person&.rapidpro_uuid.present?
      headers = { 'Authorization' => "Token #{ENV['RAPIDPRO_TOKEN']}",
                  'Content-Type'  => 'application/json' }
      url = "https://rapidpro.brl.nyc/api/v2/contacts.json?uuid=#{person.rapidpro_uuid}"
      res = HTTParty.delete(url, headers: headers)

      case res.code
      when 404
        return false
      when 204 || 201 || 200 # successful delete
        person.update_column(:rapidpro_uuid, nil) # skip callbacks
        return true
      when 429
        retry_delay = res.headers['retry-after'].to_i + 5
        RapidproDeleteJob.perform_in(retry_delay, id)
      else
        raise 'error'
      end
    else
      raise 'error' # no person found
    end
  end
end
# rubocop:enable Style/StructInheritance
