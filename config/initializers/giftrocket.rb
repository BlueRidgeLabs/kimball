# frozen_string_literal: true

# require 'giftrocket'
# Giftrocket.configure do |config|
#   config[:access_token] = Rails.application.credentials.giftrocket[:api_key]
#   config[:base_api_uri] = Rails.application.credentials.giftrocket[:endpoint]
# end

require 'tremendous'

Tremendous::Client ||=  Tremendous::Rest.new(
    Rails.application.credentials.tremendous[:api_token],
    Rails.application.credentials.tremendous[:endpoint]
  )

if Tremendous::Client.webhooks.list.empty?
  raise "no tremendous webhooks created!"
end if ['production','staging'].include? Rails.env 
