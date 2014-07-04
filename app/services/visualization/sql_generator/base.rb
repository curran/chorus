module Visualization
  module SqlGenerator
    class Base

      private

      def relation(dataset)
        @relation ||= Arel::Table.new(dataset.scoped_name)
      end
    end
  end
end
