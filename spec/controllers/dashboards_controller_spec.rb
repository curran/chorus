require 'spec_helper'

describe DashboardsController do
  let(:user) { users(:the_collaborator) }
  let(:params) { {:entity_type => entity_type} }

  before do
    log_in user
  end

  describe '#show' do
    before do
      get :show, params
    end

    context 'with an unknown entity_type' do
      let(:entity_type) { 'unreal' }

      it 'returns 422' do
        response.should be_unprocessable
        decoded_errors.fields.entity_type.should have_key :INVALID
      end
    end

    context 'with entity_type site_snapshot' do
      let(:entity_type) { 'site_snapshot' }

      it 'returns 200' do
        response.should be_ok
      end

      it 'includes the entity_type' do
        decoded_response.entity_type.should == entity_type
      end

      it 'includes stats for Workfiles, Users, Workspaces, and AssociatedDatasets' do
        decoded_response.data.length.should == 4
        %w(workfile user workspace associated_dataset).each do |key|
          decoded_response.data.detect { |o| o[:model] == key }.should_not be_nil
        end
      end

      generate_fixture 'dashboard/siteSnapshot.json' do
        get :show, params
      end
    end
  end
end
