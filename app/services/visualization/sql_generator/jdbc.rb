module Visualization
  module SqlGenerator
    class Jdbc < Base
      def frequency_row_sql(dataset, bins, category, filters)
        query = <<-SQL
          SELECT TOP #{bins} #{category} AS bucket, count(1) AS counted
            FROM #{dataset.scoped_name}
              GROUP BY #{category}
              ORDER BY counted DESC
        SQL
        query << " WHERE #{filters.join(' AND ')}" if filters.present?
        query
      end
    end
  end
end
