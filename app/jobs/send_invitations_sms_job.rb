# app/jobs/twilio/send_messages.rb
#
# module TwilioSender
# Send twilio messages to a list of phone numbers
#
# FIXME: Refactor and re-enable cop
# rubocop:disable Style/StructInheritance
#
class SendInvitationsSmsJob < Struct.new(:to, :invitation)

  def enqueue(job)
    Rails.logger.info '[SendInvitationsSms] job enqueued'
    job.save!
  end

  def max_attempts
    1
  end

  # FIXME: Refactor and Enable Cops!
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

  def perform
    # step 1: check to see if we already have a context for the person
    #   yes: get ttl and re-enque for after ttl
    #   no: go to step 2
    # step 2: check if we are after hours
    #   yes: requeue for 8:30am
    #   no: set context with expire and send!

    lock = Redis.current.get("invite_lock:#{to.id}")
    if lock.nil? # && !time_requeue? # no lock, not too late
      Rails.logger.info 'not locked!'

      # this is where we lock. the invitation to this event.
      Redis.current.setex("invite_lock:#{to.id}", 7200, invitation.id)

      InvitationSms.new(to: to, session: session).send
    elsif time_requeue?
      Rails.logger.info 'after business hours'
      Delayed::Job.enqueue(SendInvitationsSmsJob.new(to, invitation), run_at: run_in_business_hours)
    else # person is locked, wait till the lock times out.
      ttl = Redis.current.ttl("invite_lock:#{to.id}") # ttl is in seconds
      Rails.logger.info "puts locked for #{ttl}"
      Delayed::Job.enqueue(SendInvitationsSmsJob.new(to, invitation), run_at: ttl.seconds.from_now)
    end
    sleep(1) # twilio rate limiting.
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def before(job); end

  def after(job); end

  def success(job); end

  private

    def time_requeue?
      # yes if before 8:30am and yes if after 8pm
      return true if Time.current < DateTime.current.change({ hour: 8, minute: 30 })
      return true if Time.current > DateTime.current.change({ hour: 20, minute: 0 })

      false
    end

    def run_in_business_hours   # different run_at times
      if Time.current > Time.zone.parse('20:00')
        DateTime.tomorrow.change({ hour: 8, minute: 30 })
      elsif Time.current < Time.zone.parse('8:00')
        DateTime.current.change({ hour: 8, minute: 30 })
      end
    end
end
# rubocop:enable Style/StructInheritance