require File.join(File.dirname(__FILE__), '../config/environment')

module Supplismo
  class App < Sinatra::Base
    helpers Sinatra::JSON
    helpers Sinatra::Cookies
    register Sinatra::ConfigFile

    class << self
      def config_file_path
        path = "#{File.dirname(__FILE__)}/../config/configure.yml"
        path += '.example' unless File.exists?(path)
        path
      end
    end

    config_file config_file_path

    use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :expire_after => 2592000,
                           :secret => settings.cookie_secret

    configure do
      set :cookie_options, { httponly: false }
    end

    configure :development do
      register Sinatra::Reloader
    end

    configure :production, :development do
      enable :logging
    end

    JSON_PARAMS = {:only => [:id, :text], :methods => [:status_id, :class_name]}

    def html(view)
      File.read File.join(File.dirname(__FILE__), 'public', "#{view.to_s}.html")
    end

    get '/' do
      cookies[:user_token] = SecureRandom.hex unless cookies.has_key?(:user_token)
      html :index
    end

    get '/stocks' do
      Stock.all.to_json(JSON_PARAMS)
    end

    post '/stocks' do
      unless params[:name].nil?
        stock = Stock.new
        stock.text = params[:name]
        stock.save
      end
    end

    before '/stocks/:id' do
      @stock = Stock.get(params[:id].to_i)
    end

    get '/stocks/:id' do
      @stock.to_json(JSON_PARAMS)
    end

    put '/stocks/:id' do
      s = JSON.parse(request.body.read.to_s)
      @stock.status = s['status'] unless s['status'].nil?
      @stock.save
      @stock.to_json(JSON_PARAMS)
    end

    delete '/stocks/:id' do
      @stock.destroy
    end

    # SpecialRequest

    get '/requests' do
      requests = SpecialRequest.all
      requests.count > 0 ? requests.to_json : "[]"
    end

    post '/requests' do
      r = JSON.parse(request.body.read.to_s)
      unless r['text'].nil?
        special_request = SpecialRequest.create(text: r['text'], user_token: r['user_token'])
        status 201
        special_request.to_json
      end
    end

    delete '/requests/:id' do
      request = SpecialRequest.get(params[:id].to_i)
      if request && (request.user_token == cookies[:user_token] || Authentication.new(settings.admin_password, session).admin?)
        request.destroy
      else
        status 404
      end
    end

    # Authentication

    before '/authentication' do
      @auth = Authentication.new(settings.admin_password, session)
    end

    post '/authentication' do
      p = JSON.parse(request.body.read.to_s)
      status 403 unless @auth.authenticate(p["password"])
    end

    get '/authentication' do
      status 403 unless @auth.admin?
    end

    delete '/authentication' do
      status 500 unless @auth.destroy
    end

    run! if app_file == $0
  end
end
