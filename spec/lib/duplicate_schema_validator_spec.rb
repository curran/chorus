require 'spec_helper'

def add_index
  unless conn.index_exists? :schemas, [:name, :parent_id, :parent_type], :unique => true
    conn.add_index :schemas, [:name, :parent_id, :parent_type], :unique => true
  end
end

def remove_index
  if conn.index_exists? :schemas, [:name, :parent_id, :parent_type], :unique => true
    conn.remove_index :schemas, :column => [:name, :parent_id, :parent_type]
  end
end

describe DuplicateSchemaValidator do
  let(:conn) { ActiveRecord::Base.connection }

  describe ".run" do
    context "when the unique index exists" do
      before do
        add_index
      end

      it "returns true" do
        DuplicateSchemaValidator.run.should be_true
      end
    end

    context "when the unique index does not exist" do
      before do
        remove_index
      end

      context "when there are duplicate schema names" do
        before do
          datasource = data_sources(:oracle)
          2.times do
            schema = OracleSchema.new
            schema.name = "duplicate_schema"
            schema.parent = datasource
            schema.save!(:validate => false)
          end
        end

        it "returns false" do
          DuplicateSchemaValidator.run.should be_false
        end

        it "logs duplicate schemas if a logger is set" do
          logger = Object.new
          mock(logger).info(anything)

          DuplicateSchemaValidator.logger = logger
          DuplicateSchemaValidator.run

          DuplicateSchemaValidator.logger = nil
        end
      end

      context "when there are no duplicate schema names" do
        it "returns true" do
          DuplicateSchemaValidator.run.should be_true
        end
      end
    end

  end

  describe ".run_and_fix" do
    context "when the unique index exists" do
      before do
        add_index
      end

      it "returns true" do
        DuplicateSchemaValidator.run_and_fix.should be_true
      end
    end

    context "when the unique index does not exist" do
      before do
        remove_index
      end

      context "when there are no duplicate schemas" do
        it "returns true" do
          DuplicateSchemaValidator.run_and_fix.should be_true
        end
      end

      context "when there are duplicate schemas" do
        let(:database) { gpdb_databases(:default) }
        let(:duplicate_schemas_in_database) {
          Schema.where(
              :name => "duplicate_schema",
              :parent_id => database.id,
              :parent_type => "GpdbDatabase"
          )
        }

        let!(:duplicate_schema_objects) {
          Array.new(2) do
            schema = GpdbSchema.new
            schema.name = "duplicate_schema"
            schema.parent = database
            schema.save!(:validate => false)
            schema
          end
        }

        it "returns true" do
          DuplicateSchemaValidator.run_and_fix.should be_true
        end

        it "logs duplicate destroying schemas" do
          logger = Object.new
          mock(logger).info(anything)

          DuplicateSchemaValidator.logger = logger
          DuplicateSchemaValidator.run_and_fix

          DuplicateSchemaValidator.logger = nil
        end

        it "removes the duplicate schemas" do
          DuplicateSchemaValidator.run_and_fix
          duplicate_schemas_in_database.count.should eq(1)
        end

        it "even removes soft deleted duplicates! WOW!" do
          duplicate_schemas_in_database.destroy_all

          DuplicateSchemaValidator.run_and_fix
          duplicate_schemas_in_database.count.should eq(1)
        end

        it "links workfiles to the remaining schemas" do
          workfile1 = FactoryGirl.create(:chorus_workfile, :execution_schema => duplicate_schema_objects[0])
          workfile2 = FactoryGirl.create(:chorus_workfile, :execution_schema => duplicate_schema_objects[1])

          DuplicateSchemaValidator.run_and_fix

          workfile1.reload.execution_schema.should eq(duplicate_schemas_in_database.first)
          workfile2.reload.execution_schema.should eq(duplicate_schemas_in_database.first)
        end

        it "links workspaces to the remaining schemas" do
          workspace1 = FactoryGirl.create(:workspace, :sandbox => duplicate_schema_objects[0])
          workspace2 = FactoryGirl.create(:workspace, :sandbox => duplicate_schema_objects[1])

          DuplicateSchemaValidator.run_and_fix

          workspace1.reload.sandbox.should eq(duplicate_schemas_in_database.first)
          workspace2.reload.sandbox.should eq(duplicate_schemas_in_database.first)
        end

        it "links chorus views to the remaining schema" do
          chorusview1 = FactoryGirl.create(:chorus_view, :schema => duplicate_schema_objects[0])
          chorusview2 = FactoryGirl.create(:chorus_view, :schema => duplicate_schema_objects[1])

          DuplicateSchemaValidator.run_and_fix

          chorusview1.reload.schema.should eq(duplicate_schemas_in_database.first)
          chorusview2.reload.schema.should eq(duplicate_schemas_in_database.first)
        end

        it "deletes duplicate datasets" do
          dataset1 = FactoryGirl.create(:gpdb_table, :name => 'duplicate_table', :schema => duplicate_schema_objects[0])
          dataset2 = FactoryGirl.create(:gpdb_table, :name => 'duplicate_table', :schema => duplicate_schema_objects[1])

          DuplicateSchemaValidator.run_and_fix

          ((Dataset.find_by_id(dataset1.id) ? 1 : 0) + (Dataset.find_by_id(dataset2.id) ? 1 : 0)).should == 1
        end

        it "handles the duplicate schemas having mismatched dataset sets" do
          FactoryGirl.create(:gpdb_table, :name => 'duplicate_table1', :schema => duplicate_schema_objects[0])
          FactoryGirl.create(:gpdb_table, :name => 'duplicate_table2', :schema => duplicate_schema_objects[1])

          DuplicateSchemaValidator.run_and_fix

          Dataset.where(:schema_id => duplicate_schemas_in_database.first.id).count.should eq(2)
        end

        it "links activities for duplicate datasets to datasets in the remaining schema" do
          activity_lists = duplicate_schema_objects.map do |schema|
            dataset = FactoryGirl.create(:gpdb_table, :schema => schema, :name => 'duplicate_dataset')
            activities = Events::DatasetImportCreated.by(users(:owner)).add(
                :workspace => workspaces(:public),
                :dataset => nil, :source_dataset => dataset,
                :destination_table => 'other_table'
            ).activities

            activities.select { |activity| activity.entity_id == dataset.id }
          end

          DuplicateSchemaValidator.run_and_fix

          activity_lists.each do |activities|
            activities.each do |activity|
              activity.reload.entity.should eq(duplicate_schemas_in_database.first.datasets.first)
            end
          end
        end

        it "links event target1 for duplicate datasets to datasets in the remaining schema" do
          events = duplicate_schema_objects.map do |schema|
            dataset = FactoryGirl.create(:gpdb_table, :schema => schema, :name => 'duplicate_dataset')
            Events::DatasetImportCreated.by(users(:owner)).add(
                :workspace => workspaces(:public),
                :dataset => nil, :source_dataset => dataset,
                :destination_table => 'other_table'
            )
          end

          DuplicateSchemaValidator.run_and_fix

          events.each do |event|
            event.reload.target1.should eq(duplicate_schemas_in_database.first.datasets.first)
          end
        end

        it "links event target2 for duplicate datasets to datasets in the remaining schema" do
          events = duplicate_schema_objects.map do |schema|
            dataset = FactoryGirl.create(:gpdb_table, :schema => schema, :name => 'duplicate_dataset')
            Events::DatasetImportCreated.by(users(:owner)).add(
                :workspace => workspaces(:public),
                :dataset => dataset, :source_dataset => datasets(:table),
                :destination_table => 'other_table'
            )
          end

          DuplicateSchemaValidator.run_and_fix

          events.each do |event|
            event.reload.target2.should eq(duplicate_schemas_in_database.first.datasets.first)
          end
        end

        it "links associated datasets for duplicate datasets to datasets in the remaining schema" do
          workspaces = duplicate_schema_objects.map do |schema|
            dataset = FactoryGirl.create(:gpdb_table, :schema => schema, :name => 'duplicate_dataset')
            workspace = FactoryGirl.create(:workspace)
            workspace.bound_datasets << dataset
            workspace
          end

          DuplicateSchemaValidator.run_and_fix

          workspaces.each do |workspace|
            workspace.bound_datasets.where(
                :id => duplicate_schemas_in_database.first.datasets.first
            ).count.should eq(1)
          end
        end

        it "links import schedules for duplicate datasets to datasets in the remaining schema" do
          schedules = duplicate_schema_objects.map do |schema|
            dataset = FactoryGirl.create(:gpdb_table, :schema => schema, :name => 'duplicate_dataset')
            schedule = ImportSchedule.new()
            schedule.source_dataset = dataset
            any_instance_of(ImportSchedule) do |sched|
              stub(sched).set_next_import { }
            end
            schedule.save!(:validate => false)
            schedule
          end

          DuplicateSchemaValidator.run_and_fix

          schedules.each do |schedule|
            schedule.reload.source_dataset.should eq(duplicate_schemas_in_database.first.datasets.first)
          end
        end

        it "links imports for duplicate datasets to datasets in the remaining schema" do
          imports = duplicate_schema_objects.map do |schema|
            dataset = FactoryGirl.create(:gpdb_table, :schema => schema, :name => 'duplicate_dataset')
            import = Import.new
            import.source_dataset = dataset
            import.save!(:validate => false)
            import
          end

          DuplicateSchemaValidator.run_and_fix

          imports.each do |import|
            import.reload.source_dataset.should eq(duplicate_schemas_in_database.first.datasets.first)
          end
        end

      end
    end
  end
end
