module Visualization
  module SqlGenerator
    class PgLike < Base
      def frequency_row_sql(dataset, bins, category, filters)
        relation = relation(dataset)

        query = relation.
            group(relation[category]).
            project(relation[category].as('bucket'), Arel.sql('count(1)').as('count')).
            order(Arel.sql('count').desc).
            take(bins)
        query = query.where(Arel.sql(filters.join(' AND '))) if filters.present?

        query.to_sql
      end
    end
  end
end
