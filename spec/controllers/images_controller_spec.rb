require "spec_helper"

describe ImagesController do
  describe "#update" do
    before do
      @user = FactoryGirl.create(:user, :username => 'some_user', :first_name => "marty")
      User.any_instance.stub(:save_attached_files).and_return(true)
      log_in @user
    end

    it "updates the user's image" do
      @user.image.url.should == "/images/original/missing.png"
      put :update, :id => @user.id, :files => [Rack::Test::UploadedFile.new(File.expand_path("spec/fixtures/small.png", Rails.root), "image/jpeg")]
      @user.reload
      @user.image.url.should_not == "/images/original/missing.png"
    end
  end
end
