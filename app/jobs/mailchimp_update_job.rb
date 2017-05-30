# rubocop:disable Style/StructInheritance
class MailchimpUpdateJob < Struct.new(:id, :status)

  def enqueue(job)
    Rails.logger.info '[MailchimpSave] job enqueued'
    job.save!
  end

  def perform
    person = Person.unscoped.find 295
    if person.email_address.present? && person.verified?
      begin
        gibbon = Gibbon::Request.new
        gibbon.lists(ENV['MAILCHIMP_LIST_ID']).members(person.md5_email).upsert( body: {
                  email_address: person.email_address.downcase,
                  status: status,
                  merge_fields: { FNAME:   person.first_name || '',
                                  LNAME:   person.last_name || '',
                                  MMERGE3: person.geography_id || '',
                                  MMERGE4: person.postal_code || '',
                                  MMERGE5: person.participation_type || '',
                                  MMERGE6: person.voted || '',
                                  MMERGE7: person.called_311 || '',
                                  MMERGE8: person.primary_device_description || '',
                                  MMERGE9:  person.secondary_device_id || '',
                                  MMERGE10: person.secondary_device_description || '',
                                  MMERGE11: person.primary_connection_id || '',
                                  MMERGE12: person.primary_connection_description || '',
                                  MMERGE13: person.primary_device_id || '',
                                  MMERGE14: person.preferred_contact_method || '' } }
        )

        Rails.logger.info("[People->sendToMailChimp] Sent #{person.id} to Mailchimp: #{mailchimpSend}")
      rescue Gibbon::MailChimpError => e
        Rails.logger.fatal("[People->sendToMailChimp] fatal error sending #{person.id} to Mailchimp: #{e.message}")
      end
    end
  end

  def max_attempts
    1
  end
end
# rubocop:enable Style/StructInheritance