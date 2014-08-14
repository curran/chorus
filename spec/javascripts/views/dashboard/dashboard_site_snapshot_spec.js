describe("chorus.views.DashboardSiteSnapshot", function() {
    beforeEach(function() {
        this.view = new chorus.views.DashboardSiteSnapshot();
        this.siteSnapshotAttrs = backboneFixtures.dashboard.siteSnapshot().attributes;
    });

    describe("setup", function() {
        it("fetches the site snapshot data", function() {
            expect(this.server.lastFetch().url).toBe('/dashboards?entity_type=site_snapshot');
        });

        context("when the fetch completes", function() {
            beforeEach(function() {
                this.server.lastFetch().respondJson(200, this.siteSnapshotAttrs);
            });

            it("has a title", function() {
                expect(this.view.$('.title')).toContainTranslation("dashboard.site_snapshot.name");
            });

            it("displays the snapshot data", function() {
                expect(this.view.$('.square').length).toBe(4);
                _.each(this.siteSnapshotAttrs.data, function(one) {
                    expect(this.view.$("." + one.model)).toContainTranslation("dashboard.site_snapshot." + one.model, {count:one.total});
                    expect(this.view.$("." + one.model)).toContainText(one.total);
                    expect(this.view.$("." + one.model)).toContainTranslation("dashboard.site_snapshot.increment", {inc:one.increment});
                }, this);
            });
        });
    });
});
