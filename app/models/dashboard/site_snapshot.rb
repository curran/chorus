module Dashboard
  class SiteSnapshot
    ENTITY_TYPE = 'site_snapshot'

    attr_accessor :result

    def initialize(params)
    end

    def entity_type
      ENTITY_TYPE
    end

    def fetch!
      @result = [Workfile, Workspace, User, Events::Base].inject({}) do |memo, model|
        memo[model.to_s.underscore.pluralize.to_sym] = {
            :total => model.count,
            :increment => model.where('"created_at" > ?', 7.days.ago).count
        }
        memo
      end

      self
    end
  end
end
