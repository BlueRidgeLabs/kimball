# frozen_string_literal: true

# == Schema Information
#
# Table name: invitations
#
#  id                  :integer          not null, primary key
#  person_id           :integer
#  created_at          :datetime
#  updated_at          :datetime
#  research_session_id :integer
#  aasm_state          :string(255)
#

# FIXME: Refactor and re-enable cop
class Invitation < ActiveRecord::Base
  has_paper_trail

  include AASM
  include Calendarable

  belongs_to :person
  belongs_to :research_session
  validates :person, presence: true

  # so users can take notes.
  has_many :comments, as: :commentable, dependent: :destroy

  # this is how we give gift cards for sessions.
  has_many :gift_cards, as: :giftable, dependent: :destroy

  # one person can't have multiple invitations for the same event
  validates :person, uniqueness: { scope: :research_session }

  # not sure about all these delegations.
  delegate :user,
    :start_datetime,
    :end_datetime,
    :title,
    :description,
    :location,
    :sms_description,
    :duration, to: :research_session

  scope :today, -> {
    joins(:research_session).
      where(research_sessions: { start_datetime: Time.zone.today.beginning_of_day..Time.zone.today.end_of_day })
  }

  scope :future, -> {
    joins(:research_session).
      where('research_sessions.start_datetime > ?',
        Time.zone.today.end_of_day)
  }

  scope :past, -> {
    joins(:research_session).
      where('research_sessions.start_datetime < ?',
        Time.zone.today.beginning_of_day)
  }

  scope :upcoming, ->(d = 7) {
    joins(:research_session).
      where(research_sessions: { start_datetime: Time.zone.today.beginning_of_day..Time.zone.today.end_of_day + d.days })
  }

  scope :remindable, -> {
    where(aasm_state: %w[invited reminded confirmed])
  }

  scope :confirmable, -> {
    where.not(aasm_state: %w[attended
                             cancelled
                             created
                             missed])
  }
  # invitations can move through states
  # necessary for text messaging bits in the future
  aasm do
    state :created, initial: true
    state :invited
    state :reminded
    state :confirmed
    state :cancelled # means that they cancelled ahead of time
    state :missed # means they didn't cancel
    state :attended

    event :invite, after_commit: :send_invitation, guard: :in_future? do
      transitions from: :created, to: :invited
    end

    event :remind, after_commit: :send_reminder, guard: :in_future? do
      transitions from: %i[invited reminded confirmed], to: :reminded
    end

    event :confirm, after_commit: :notify_about_confirmation, guard: :in_future? do
      transitions from: %i[confirmed invited reminded], to: :confirmed
    end

    event :cancel, after_commit: :notify_about_cancellation, guard: :in_future? do
      transitions from: %i[invited cancel reminded confirmed], to: :cancelled
    end

    event :attend do
      # can transition from anything to attended.
      transitions to: :attended
    end

    event :miss, guard: :in_past? do
      # should this be able to transition from "attended" ?
      transitions from: %i[invited reminded confirmed], to: :missed
    end
  end

  def self.send_reminders
    Invitation.upcoming(1).remindable.find_each(&:remind!)
  end

  def owner_or_invitee?(person_or_user)
    # both people and users can own a invitation.
    return true if user == person_or_user
    return true if person == person_or_user
    return false if person_or_user.nil?
    false
  end

  def send_invitation
    case person.preferred_contact_method.upcase
    when 'SMS'
      send_invite_sms
    when 'EMAIL'
      send_invite_email
    end
  end

  def send_invite_email
    ::PersonMailer.invite(
      invitation:  self,
      person: person
    ).deliver_later
  end

  def send_invite_sms
    ::InvitationSms.new(to: person, invitation: self).send
  end

  def send_reminder
    case person.preferred_contact_method.upcase
    when 'SMS'
      ::InvitationReminderSms.new(to: person, invitations: [self]).send
    when 'EMAIL'
      ::PersonMailer.remind(invitations: [self], email_address: person.email_address).deliver_now
    end
  end

  # these three could definitely be refactored. too much copy-paste
  # also rename for nomenclature convention
  def notify_about_confirmation
    ::PersonMailer.confirm(email_address: user.email, invitation: self).deliver_later
    case person.preferred_contact_method.upcase
    when 'SMS'
      ::InvitationConfirmSms.new(to: person, invitation: self).send
    when 'EMAIL'
      ::PersonMailer.confirm(email_address: person.email_address, invitation: self).deliver_later
    end
  end

  def notify_about_cancellation
    # notify the user
    ::PersonMailer.cancel(email_address: user.email, invitation: self).deliver_later

    case person.preferred_contact_method.upcase
    when 'SMS'
      ::InvitationCancelSms.new(to: person, invitation: self).send
    when 'EMAIL'
      ::PersonMailer.cancel(email_address: person.email_address, invitation: self).deliver_later
    end
  end

  def permitted_events
    aasm.events.call(permitted: true).map(&:name).map(&:to_s)
  end

  def permitted_states
    aasm.states(permitted: true).map(&:name).map(&:to_s)
  end

  def state_action_array
    permitted_events.each_with_index.map do |e, i|
      [permitted_states[i], e]
    end
  end

  def in_future?
    Time.zone.now < start_datetime
  end

  def in_past?
    Time.zone.now < start_datetime
  end

  def human_state
    case aasm_state
    when 'created' || 'reminded'
      'Unconfirmed'
    when 'rescheduled'
      'Rescheduling'
    else
      aasm_state.capitalize
    end
  end

end
# rubocop:enable ClassLength
