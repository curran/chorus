module Visualization
  class Timeseries < Base
    attr_accessor :rows, :time, :value, :time_interval, :aggregation, :filters, :type

    def post_initialize(dataset, attributes)
      @type = attributes[:type]
      @time = attributes[:x_axis]
      @value = attributes[:y_axis]
      @time_interval = attributes[:time_interval]
      @aggregation = attributes[:aggregation]
      @filters = attributes[:filters]
    end

    def complete_fetch(check_id)
      result = CancelableQuery.new(@connection, check_id, current_user).execute(row_sql)

      raise ApiValidationError.new(:base, :too_many_rows) if result.rows.count > 1000
      @rows = result.rows.map { |row| {:value => row[0].to_f.round(3), :time => row[1]} }
    end

    private

    def build_row_sql
      date_trunc = "date_trunc('#{@time_interval}' ,\"#{@time}\")"

      query = relation.
        group(Arel.sql(date_trunc)).
        project(Arel.sql("#{@aggregation}(\"#{@value}\"), to_char(#{date_trunc}, '#{pattern}') ")).
        order(Arel.sql(date_trunc).asc)
      query = query.where(Arel.sql(@filters.join(" AND "))) if @filters.present?

      query.to_sql
    end

    def pattern
      if "day" == @time_interval || "week"==@time_interval
        pattern = "yyyy-MM-dd"
      elsif "month"== @time_interval
        pattern = "yyyy-MM"
      elsif "year"== @time_interval
        pattern = "yyyy"
      else
        pattern = "yyyy-MM-dd hh:mm:ss"
      end

      pattern
    end
  end
end
