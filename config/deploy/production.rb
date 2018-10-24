set :application, 'logan-production'
set :branch, fetch(:branch, ENV['PRODUCTION_BRANCH'])
# use the same ruby as used locally for deployment
set :rvm_ruby_string, '2.5.3@production'

server ENV['PRODUCTION_SERVER'], :app, :web, :db, primary: true
