# frozen_string_literal: true

json.array!(@people) do |person|
  json.extract! person, :first_name, :last_name, :email_address, :address_1, :address_2, :city, :state, :postal_code, :geography_id, :primary_device_id, :primary_device_description, :secondary_device_id, :secondary_device_description, :primary_connection_id, :primary_connection_description, :phone_number, :participation_type
  json.url person_url(person, format: :json)
end
