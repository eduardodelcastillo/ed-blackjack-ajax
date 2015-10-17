require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'lana' 

get '/inline' do 
  "Hi, directly from the action!"
end

get '/template' do
  erb :mytemplate
end

get '/nested_template' do
  erb :"users/profile"
end

get '/not_here' do 
  redirect '/template'
end

get '/form' do
  erb :form
end

post '/myaction' do 
  erb :"users/profile"
end