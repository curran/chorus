module Dashboard
  class BasePresenter < Presenter
    def to_hash
      model.result.merge!(:entity_type => model.entity_type)
    end
  end
end
