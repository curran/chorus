class DashboardConfigPresenter < Presenter

  def to_hash
    modules = model.dashboard_items

    {
        :user_id => model.user.id,
        :modules => modules,
        :available_modules => DashboardItem::ALLOWED_MODULES - modules
    }
  end
end
