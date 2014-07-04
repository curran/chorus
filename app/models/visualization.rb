require 'visualization/sql_generator/base'

module Visualization
  UnknownType = Class.new(StandardError)

  def self.build(dataset, attributes)
    case attributes[:type]
      when 'frequency' then Visualization::Frequency
      when 'histogram' then Visualization::Histogram
      when 'heatmap' then Visualization::Heatmap
      when 'timeseries' then Visualization::Timeseries
      when 'boxplot' then Visualization::Boxplot
      else raise UnknownType, "Unknown visualization: #{attributes[:type]}"
    end.new(dataset, attributes)
  end

  class Base
    include CurrentUser

    attr_writer :dataset, :schema, :connection, :sql_generator

    def initialize(dataset=nil, attributes={})
      @dataset = dataset
      @schema = dataset.try :schema
      post_initialize(dataset, attributes)
    end

    def fetch!(account, check_id)
      @connection = @dataset.connect_with(account)
      @sql_generator = @connection.visualization_sql_generator
      complete_fetch(check_id)
    end

    def post_initialize(dataset, attributes); end

    def complete_fetch(check_id); end

    def row_sql
      @dataset.query_setup_sql + build_row_sql
    end

    def min_max_sql
      @dataset.query_setup_sql + build_min_max_sql
    end

    # remove when all viz use sql generator
    def relation
      @relation ||= Arel::Table.new(@dataset.scoped_name)
    end
  end
end
