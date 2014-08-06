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

            it("displays the snapshot data", function() {
                expect(this.view.$('.square').length).toBe(4);
            });
        });
    });
});
