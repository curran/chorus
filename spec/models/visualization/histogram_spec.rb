require 'spec_helper'

describe Visualization::Histogram do
  let(:schema) { FactoryGirl.build_stubbed(:gpdb_schema, :name => 'analytics') }
  let(:dataset) { FactoryGirl.build_stubbed(:gpdb_table, :name => '2009_sfo_customer_survey', :schema => schema) }
  let(:data_source_account) { FactoryGirl.build_stubbed(:data_source_account) }
  let(:user) { data_source_account.owner }
  let(:connection) {
    object = Object.new
    stub(object).visualization_sql_generator { Visualization::SqlGenerator::Base.new }
    stub(schema).connect_with(data_source_account) { object }
    object
  }
  before do
    set_current_user(user)
  end

  describe "#fetch!" do
    it "returns visualization structure" do
      visualization = described_class.new(dataset, {
          :bins => 3,
          :x_axis => 'airport_cleanliness'
      })

      mock(CancelableQuery).new(connection, 17, user) do
        mock(Object.new).execute(visualization.build_min_max_sql) do
          GreenplumSqlResult.new.tap do |result|
            result.add_column("min", "double")
            result.add_column("max", "double")
            result.add_rows([['1.0', '9.0']])
          end
        end
      end

      visualization.instance_variable_set(:@min, "1.0")
      visualization.instance_variable_set(:@max, "9.0")
      mock(CancelableQuery).new(connection, 17, user) do
        mock(Object.new).execute(visualization.build_row_sql) do
          GreenplumSqlResult.new.tap do |result|
            result.add_column("bin", "text")
            result.add_column("frequency", "int8")
            result.add_rows([
              ['1', '2'],
              ['3', '6'],
              ['4', '9']
            ])
          end
        end
      end

      visualization.fetch!(data_source_account, 17)

      visualization.rows.should include({:bin => [1.0, 3.7], :frequency => 2})
      visualization.rows.should include({:bin => [3.7, 6.3], :frequency => 0})
      visualization.rows.should include({:bin => [6.3, 9.0], :frequency => 15})
    end
  end

  context 'integration' do
    let(:schema_name) { 'test_schema' }
    let(:table_name) { 'base_table1' }

    context 'for gpdb', :greenplum_integration do
      let(:data_source_account) { GreenplumIntegration.real_account }
      let(:database) { GpdbDatabase.find_by_name_and_data_source_id(GreenplumIntegration.database_name, GreenplumIntegration.real_data_source)}

      context 'with a table' do
        let(:dataset) { database.find_dataset_in_schema(table_name, schema_name) }

        it_behaves_like 'a histogram visualization'
      end

      context 'with a chorus view' do
        let(:dataset) do
          ChorusView.new({:name => 'CHORUS_VIEW',
                          :schema => database.schemas.find_by_name!(schema_name),
                          :query => "select * from #{table_name}"
                         }, :without_protection => true)
        end

        it_behaves_like 'a histogram visualization'
      end
    end

    context 'for postgres', :postgres_integration do
      let(:data_source_account) { PostgresIntegration.real_account }
      let(:database) { PostgresIntegration.real_database }
      let(:dataset) { database.find_dataset_in_schema(table_name, schema_name) }

      it_behaves_like 'a histogram visualization'
    end
  end
end
