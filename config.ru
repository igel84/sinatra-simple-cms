require 'bootstrap.rb'
run Sinatra::Application
#%w(sinatra bootstrap).each { |lib| require lib }
#run Sinatra::Application