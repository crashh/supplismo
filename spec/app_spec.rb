require 'spec_helper.rb'

def app
  Supplismo::App.new
end

describe 'site' do
  it "page ok" do
    get "/"
    last_response.should be_ok
  end

  it "content" do
    get "/"
    last_response.body.should include('<html ng-app="app">')
  end
end

describe 'stocks API' do
  before {
    Supplismo::Stock.all.destroy
  }

  describe 'GET stocks' do
    before {
      @stock = Supplismo::Stock.create(text: 'text', status_id: 0)
      get '/stocks'
    }

    it { last_response.should be_ok }
    it { last_response.body.should include(@stock.to_json(Supplismo::App::JSON_PARAMS)) }
  end

  describe 'POST stocks' do
    it {
      Supplismo::Stock.count.should be == 0
      post '/stocks', { name: 'text' }
      Supplismo::Stock.count.should be == 1
      Supplismo::Stock.first.text.should be == 'text'
    }
  end

  describe 'GET stocks/:id' do
    before {
      @stock = Supplismo::Stock.create(text: 'text', status_id: 0)
      get "/stocks/#{@stock.id}"
    }

    it { last_response.should be_ok }
    it { last_response.body.should be == @stock.to_json(Supplismo::App::JSON_PARAMS) }
  end

  describe 'PUT stocks/:id' do
    it {
      stock = Supplismo::Stock.create(text: 'text', status_id: 0)
      put "/stocks/#{stock.id}", { status: 'medium' }.to_json, content_type: 'application/json'
      last_response.status.should eql(200)
      Supplismo::Stock.first.reload.status_id.should be == 2
    }
  end

  describe 'DELETE stocks/:id' do
    it {
      stock = Supplismo::Stock.create(text: 'text', status_id: 0)
      Supplismo::Stock.count.should be == 1
      delete "/stocks/#{stock.id}"
      Supplismo::Stock.count.should be == 0
    }
  end
end

describe 'request API', :type => :api do
  context 'list of requests' do
    before {
      @sr = Supplismo::SpecialRequest.create(text: 'Kielbasa')
    }

    let(:url) { '/requests' }
    specify do
      get "#{url}"

      requests_json = Supplismo::SpecialRequest.all.to_json
      last_response.status.should eql(200)
      last_response.body.should eql(requests_json)
      requests = JSON.parse(last_response.body)
      requests.any? { |r| r["text"] == "Kielbasa" }.should be_true
    end
  end

  context 'creating a request' do
    before :all do
      Supplismo::SpecialRequest.destroy
    end
    let(:url) { '/requests' }
    specify {
      post url, { text: 'YerbaMate' }.to_json, content_type: 'application/json'
      special_request = Supplismo::SpecialRequest.first(text: 'YerbaMate')

      last_response.status.should eq(201)
      last_response.body.should eq(special_request.to_json)
    }
  end
  context 'deleting request' do
    before :each do
      @request = Supplismo::SpecialRequest.create(text: 'YerbaMate', user_token: '123')
    end
    after :each do
      @request.destroy
    end

    let(:url) { "/requests/#{@request.id}" }
    context 'by owner' do
      specify {
        set_cookie "user_token=123"
        Supplismo::SpecialRequest.count.should be == 1
        delete url
        Supplismo::SpecialRequest.count.should be == 0
      }
    end
    context 'by admin' do
      specify {
        Supplismo::Authentication.any_instance.stub(:admin?).and_return(true)
        set_cookie "user_token=0123"
        Supplismo::SpecialRequest.count.should be == 1
        delete url
        Supplismo::SpecialRequest.count.should be == 0
      }
    end
    context 'by other user' do
      specify {
        set_cookie "user_token=0123"
        Supplismo::SpecialRequest.count.should be == 1
        delete url
        Supplismo::SpecialRequest.count.should be == 1
      }
    end
  end
end

describe 'authentication API', type: :api do
  let(:url) { '/authentication' }
  context 'login' do
    specify 'success' do
      Supplismo::Authentication.any_instance.stub(:authenticate).and_return(true)
      post url, { password: 'password' }.to_json, content_type: 'application/json'
      last_response.status.should eq(200)
    end
    specify 'failure' do
      Supplismo::Authentication.any_instance.stub(:authenticate).and_return(false)
      post url, { password: 'bad_passwrd' }.to_json
      last_response.status.should eq(403)
    end
  end
  context 'check' do
    specify 'success' do
      Supplismo::Authentication.any_instance.stub(:admin?).and_return(true)
      get url
      last_response.status.should eq(200)
    end
    specify 'failure' do
      Supplismo::Authentication.any_instance.stub(:admin?).and_return(false)
      get url
      last_response.status.should eq(403)
    end
  end
  context 'delete' do
    specify 'success' do
      Supplismo::Authentication.any_instance.stub(:destroy).and_return(true)
      delete url
      last_response.status.should eq(200)
    end
    specify 'failure' do
      Supplismo::Authentication.any_instance.stub(:destroy).and_return(false)
      delete url
      last_response.status.should eq(500)
    end
  end
end
