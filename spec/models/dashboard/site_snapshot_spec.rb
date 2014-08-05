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

  context 'when more models have been deleted' do
    it 'has a negative increment' do
      User.delete_all

      in_the_past do
        5.times { |i| FactoryGirl.create(:user, :username => "will_delete#{i}") }
      end

      FactoryGirl.create(:user, :username => 'safe_from_purge')

      User.destroy_all(%("username" LIKE 'will_delete%'))

      result[:users][:increment].should == -4
    end
  end

  def in_the_past(&block)
    Timecop.freeze 10.days.ago, &block
  end
end
