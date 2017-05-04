class InboxController < ApplicationController
  skip_before_action :authenticate_user!
  include Mandrill::Rails::WebHookProcessor

  # To completely ignore unhandled events (not even logging), uncomment this line
  # ignore_unhandled_events!

  # If you want unhandled events to raise a hard exception, uncomment this line
  # unhandled_events_raise_exceptions!

  # To enable authentication, uncomment this line and set your API key.
  # It is recommended you pull your API keys from environment settings,
  # or use some other means to avoid committing the API keys in your source code.
  authenticate_with_mandrill_keys! ENV['MANDRILL_WEBHOOK_SECRET_KEY']

  def handle_inbound(event_payload)
    head(:ok)
    msg =event_payload.msg

    from = msg['from_email']
    text = msg['text']
    subject = msg['subject']
    mail(to: ENV['MAILER_SENDER'],
         from: from,
         subject: subject,
         body: text).deliver_later

  end
end