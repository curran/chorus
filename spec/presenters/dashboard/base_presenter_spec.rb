require 'spec_helper'

describe Dashboard::BasePresenter, :type => :view do
  before do
    set_current_user(users(:admin))
  end

  let(:model) { Dashboard::SiteSnapshot.new.fetch! }
  let(:presenter) { described_class.new(model, view) }
  let(:hash) { presenter.to_hash }

  it 'hash should have attributes' do
    hash[:data].should == model.result
    hash[:entity_type].should == model.entity_type
  end
end
