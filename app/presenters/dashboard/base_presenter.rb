module Dashboard
  class BasePresenter < Presenter
    def to_hash
      {
          :data => model.result,
          :entity_type => model.entity_type
      }
    end
  end
end
