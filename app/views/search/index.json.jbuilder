# frozen_string_literal: true

json.array!(@results) do |result|
  json.extract! result, :id, :first_name, :last_name, :email_address, :phone_number
  json.name     [result.first_name, result.last_name].join(" ")
  json.tags     result.tag_list
  json.value    result.id
  json.url      person_url(result.id, format: :html)
end
