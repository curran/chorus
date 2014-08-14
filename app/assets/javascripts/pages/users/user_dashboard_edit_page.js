chorus.pages.UserDashboardEditPage = chorus.pages.Base.extend({
    constructorName: "UserDashboardEditPage",
    hasSubHeader: true,

    makeModel: function(userId) {
        this.model = new chorus.models.DashboardConfig({userId: userId});
    },

    setup: function() {
        this.model.fetch();
        this.mainContent = new chorus.views.UserDashboardEditView({model: this.model});
    },

    setupSubHeader: function() {
        var model = new chorus.models.Base({name: t("user.dashboard_edit.title")});
        this.subHeader = new chorus.views.SubHeader({model: model});
    }
});
