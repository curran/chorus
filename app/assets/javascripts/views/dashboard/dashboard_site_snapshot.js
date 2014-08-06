chorus.views.DashboardSiteSnapshot = chorus.views.Base.extend({
    constructorName: "DashboardSiteSnapshot",
    templateName:"dashboard/site_snapshot",

    setup: function() {
        this.model = new chorus.models.DashboardData({});
        this.requiredResources.add(this.model);
        this.model.urlParams = {entityType: 'site_snapshot'};
        this.model.fetch();
    },

    additionalContext: function () {
        return {
            dataItems: this.model.get("data")
        };
    }

});
