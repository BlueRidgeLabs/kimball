# frozen_string_literal: true
# # frozen_string_literal: true

# namespace :cut do
#   desc 'approve an user account'
#   task :approve, [:email] => [:environment] do |_t, args|
#     user = User.find_by(email: args.email)
#     if user
#       print "Approving #{user.email} ... "
#       user.approve!
#       puts 'done.'
#     else
#       puts "error: could not find user with email #{args.email}"
#     end
#   end

#   task :unapprove, [:email] => [:environment] do |_t, args|
#     user = User.find_by(email: args.email)
#     if user
#       print "Unapproving #{user.email} ... "
#       user.unapprove!
#       puts 'done.'
#     else
#       puts "error: could not find user with email #{args.email}"
#     end
#   end

#   namespace :wufoo do
#     desc 'submit a signup as if it were from wufoo'
#     task :signup, [:env] => [:environment] do |_t, args|
#       hosts = { development: 'http://localhost:8080', staging: "https://#{ENV['STAGING_SERVER']}", production: "https://#{ENV['PRODUCTION_SERVER']}" }

#       post_body = {}
#       Person::WUFOO_FIELD_MAPPING.each do |f, v|
#         default_value = "#{v.to_s.humanize} #{Process.pid}"
#         print "#{v.to_s.humanize} [#{default_value}]:"
#         $stdout.flush
#         alt_value = $stdin.gets.strip!
#         post_body[f] = alt_value.presence || default_value
#       end

#       curl_str = "curl -X POST #{hosts[args.env.to_sym]}/people #{post_body.collect { |k, v| "-d #{k}=\"#{v}\"" }.join(' ')} -d HandshakeKey=#{Patterns::Application.config.wufoo_handshake_key}"

#       puts "running: #{curl_str}"
#       `#{curl_str}`
#       puts 'done.'
#     end
#   end

#   desc 'shuffle names to kinda-anonymize data. useful for demos, etc'
#   task shuffle: :environment do
#     puts('cowardly refusing to shuffle production data!') && return if Rails.env.production?

#     Person.all.each do |person|
#       person.first_name = Faker::Name.first_name
#       person.last_name = Faker::Name.last_name
#       person.email_address = Faker::Internet.email
#       person.phone_number = Faker::PhoneNumber.cell_phone
#       begin; person.save!; rescue StandardError; puts "failed to save person #{person.id}"; end
#     end
#   end
# end
