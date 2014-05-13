require 'spec_helper'

describe PgSchema do

  describe 'associations' do
    it { should belong_to(:scoped_parent) }
    it { should have_many(:datasets) }

    describe 'database' do
      let(:schema) { schemas(:pg) }
      let(:database) { databases(:pg) }

      it 'returns the schemas parent' do
        schema.database.should == database
      end
    end
  end

  it_behaves_like 'a subclass of schema' do
    let(:schema) { schemas(:pg) }
  end

  describe '#class_for_type' do
    let(:schema) { schemas(:pg) }

    it 'should return GpdbTable and GpdbView correctly' do
      schema.class_for_type('r').should == PgTable
      schema.class_for_type('v').should == PgView
    end
  end

  it_behaves_like 'a soft deletable model' do
    let(:model) { schemas(:pg)}
  end
end
