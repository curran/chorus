require 'spec_helper'

resource 'Dashboard' do
  let(:user) { users(:admin) }

  before do
    log_in user
  end

  get '/dashboards' do

    parameter :entity_type, 'The type of dashboard to fetch'
    required_parameters :entity_type

    let(:entity_type) { 'site_snapshot' }

    example_request 'Get information to for a specific dashboard' do
      status.should == 200
    end
  end
end
