require 'spec_helper'

describe Dashboard::SiteSnapshot do

  let(:result) { described_class.new.fetch!.result }

  it 'has the counts for workfiles' do
    in_the_past { FactoryGirl.create(:workfile) }
    result[:workfiles].should == {
        :total => Workfile.count,
        :increment => Workfile.count_by_sql("SELECT COUNT(*) FROM workfiles WHERE created_at > (current_date - interval '7 days');")
    }
  end

  it 'has the counts for workspaces' do
    in_the_past { FactoryGirl.create(:workspace) }
    result[:workspaces].should == {
        :total => Workspace.count,
        :increment => Workspace.count_by_sql("SELECT COUNT(*) FROM workspaces WHERE created_at > (current_date - interval '7 days');")
    }
  end

  it 'has the counts for users' do
    in_the_past { FactoryGirl.create(:user) }
    result[:users].should == {
        :total => User.count,
        :increment => User.count_by_sql("SELECT COUNT(*) FROM users WHERE created_at > (current_date - interval '7 days');")
    }
  end

  def in_the_past(&block)
    Timecop.freeze 10.days.ago, &block
  end
end
