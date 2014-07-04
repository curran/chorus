module Visualization
  class Frequency < Base
    attr_accessor :rows, :bins, :category, :filters, :type

    def post_initialize(dataset, attributes)
      @type = attributes[:type]
      @bins = attributes[:bins]
      @category = attributes[:y_axis]
      @filters = attributes[:filters]
    end

    def complete_fetch(check_id)
      result = CancelableQuery.new(@connection, check_id, current_user).execute(row_sql)
      @rows = result.rows.map { |row| { :bucket => row[0], :count => row[1].to_i } }
    end

    private

    def build_row_sql
      @sql_generator.frequency_row_sql(@dataset, @bins, @category, @filters)
    end
  end
end
