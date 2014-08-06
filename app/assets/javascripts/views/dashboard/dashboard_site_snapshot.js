chorus.views.DashboardSiteSnapshot = chorus.views.Base.extend({
    constructorName: "DashboardSiteSnapshot",
    templateName:"dashboard/site_snapshot",

    setup: function() {
        this.model = new chorus.models.DashboardData({});
        this.requiredResources.add(this.model);
        this.model.urlParams = { entityType: 'site_snapshot' };
        this.model.fetch();
    },

    additionalContext: function () {
        return {
            dataItems: _.map(this.model.get("data"), function(item) {
                item.translation = "dashboard.site_snapshot." + item.model;
                return item;
            })
        };
    }

});
