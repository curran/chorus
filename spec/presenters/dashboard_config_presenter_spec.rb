require 'spec_helper'

describe DashboardConfigPresenter, :type => :view do
  let(:user) { users(:the_collaborator) }
  let(:model) { DashboardConfig.new user }
  let(:presenter) { described_class.new(model, view, {}) }
  let(:hash) { presenter.to_hash }

  describe '#to_hash' do

    it 'includes the configured dashbaord modules' do
      hash[:modules].should == model.dashboard_items
    end

    it 'includes the other available dashboard modules' do
      hash[:available_modules].should == (DashboardItem::ALLOWED_MODULES - model.dashboard_items)
    end

    it 'includes user id' do
      hash[:user_id].should == user.id
    end
  end
end
