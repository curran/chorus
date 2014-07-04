require 'spec_helper'

describe Visualization::Frequency do
  let(:schema_name) { 'test_schema' }
  let(:table_name) { 'base_table1' }

  context 'for gpdb', :greenplum_integration do
    let(:data_source_account) { GreenplumIntegration.real_account }
    let(:database) { GpdbDatabase.find_by_name_and_data_source_id(GreenplumIntegration.database_name, GreenplumIntegration.real_data_source)}

    context 'for a table' do
      let(:dataset) { database.find_dataset_in_schema(table_name, schema_name) }

      it_behaves_like 'a frequency visualization'
    end

    context 'for a chorus view' do
      let(:dataset) { datasets(:executable_chorus_view) }

      it_behaves_like 'a frequency visualization'
    end
  end

  context 'for postgres', :postgres_integration do
    let(:data_source_account) { PostgresIntegration.real_account }
    let(:database) { PostgresIntegration.real_database }
    let(:dataset) { database.find_dataset_in_schema(table_name, schema_name) }

    it_behaves_like 'a frequency visualization'
  end

  context 'for teradata', :jdbc_integration do
    let(:data_source_account) { JdbcIntegration.real_account }
    let(:schema) { JdbcIntegration.real_schema }
    let(:dataset) { schema.find_or_initialize_dataset(table_name) }

    it_behaves_like 'a frequency visualization'
  end
end
