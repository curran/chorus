module Dashboard
  class SiteSnapshot
    ENTITY_TYPE = 'site_snapshot'
    INCREMENT_TIME = 7.days.ago

    attr_accessor :result

    def entity_type
      ENTITY_TYPE
    end

    def fetch!
      @result = [Workfile, Workspace, User, Events::Base].inject({}) do |memo, model|
        memo[model.to_s.underscore.pluralize.to_sym] = {
            :total => model.count,
            :increment => changed_count(model)
        }
        memo
      end

      self
    end

    private

    def changed_count(model)
      count_created = model.where('"created_at" > ?', INCREMENT_TIME).count
      count_deleted = model.unscoped.where('"created_at" < ? AND "deleted_at" > ?', INCREMENT_TIME, INCREMENT_TIME).count
      count_created - count_deleted
    end
  end
end
