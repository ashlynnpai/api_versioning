#Code for creating namespaced versions of APIs, Code School, Surviving APIs with Rails

#Use namespaces to create two versions of APIs 

SurvivingRails::Application.routes.draw do
  namespace :v1 do
    resources :zombies
  end
  namespace :v2 do
    resources :zombies, except: :destroy
  end
end

#Tests that versions are pointing to the right controllers

class RoutesTest < ActionDispatch::IntegrationTest
  test 'routes to proper versions' do
    assert_generates '/v1/zombies', { controller: 'v1/zombies', action: 'index' }
    assert_generates '/v2/zombies', { controller: 'v2/zombies', action: 'index' }
  end
end

#Index action for v1 controller

module V1
  class ZombiesController < ApplicationController
    def index
      render json: Zombie.all, status: 200
    end
  end
end

#Integration tests, set the REMOTE_ADDR header

class ZombiesWithIpTest < ActionDispatch::IntegrationTest
  setup { @ip = '192.168.1.12' }

  test '/v1 returns ip and v1' do
    get '/v1/zombies', {}, { 'REMOTE_ADDR' => @ip }
    assert_equal 200, response.status
    assert_equal "#{@ip} and version one", response.body
  end

  test '/v2 returns ip and v2' do
    get '/v2/zombies', {}, { 'REMOTE_ADDR' => @ip }
    assert_equal 200, response.status
    assert_equal "#{@ip} and version two", response.body
  end
end

#Use ApplicationController to hold common code

class ApplicationController < ActionController::Base
  before_action ->{ @user_ip = request.headers['REMOTE_ADDR'] }
end

module V1
  class ZombiesController < ApplicationController
    def index
      render json: "#{@user_ip} and version one", status: 200
    end
  end
end

#create common base controller to DRY up code

module V2
  class VersionController < ApplicationController
    abstract!    
    before_action -> { log_survival_request }
  end
end


 module V2
   class HumansController < VersionController
    def index
      humans = Human.all
      render json: humans, status: 200
    end
  end
end

module V2
  class ZombiesController < VersionController
    def index
      zombies = Zombie.all
      render json: zombies, status: 200
    end
  end
end


#Creates a custom Mime Type called zombies that will read from a specific request header.

class ListingZombiesTest < ActionDispatch::IntegrationTest
  test 'show zombie from API version 1' do
    get '/zombies/1', {}, { 'Accept' => 'application/vnd.zombies.v1+json' }
    assert_equal 200, response.status
    assert_equal Mime::JSON, response.content_type
    assert_equal "This is version one", json(response.body)[:message]
  end
end


#test helper for above
class ListingZombiesTest < ActionDispatch::IntegrationTest
  test 'show zombie from API version 1' do
    get '/zombies/1', {}, { 'Accept' => 'application/vnd.zombies.v1+json' }
    assert_equal 200, response.status
    assert_equal Mime::JSON, response.content_type
    assert_equal "This is version one", json(response.body)[:message]
  end
end

#Implements the ApiVersion class to read the Mime Type from the Accept request header and then check it against a specific API version.

class ApiVersion

  def initialize(version, default_version=false) # Task 1
    @version, @default_version = version, default_version
  end

  def matches?(request)
    @default_version || check_headers(request.headers)
  end

  private
    def check_headers(headers)
      accept = headers['Accept']
      accept && accept.include?("application/vnd.zombies.#{@version}+json")
    end
end


#Uses this class on our routes file. Version 2 is the default API version!

require 'api_version'

SurvivingRails::Application.routes.draw do
  scope defaults: { format: 'json' } do
    scope module: :v1, constraints: ApiVersion.new('v1') do # Task 2
      resources :zombies
    end
    scope module: :v2, constraints: ApiVersion.new('v2', true) do # Task 3
      resources :zombies
    end
  end
end

#Update routes test to verify the default version

class RoutesTest < ActionDispatch::IntegrationTest
  test 'defaults to v2' do
    assert_generates '/zombies', # Task 1
    { controller: 'v2/zombies', action: 'index' } # Task 2
  end
end
