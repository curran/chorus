describe("chorus.views.UserDashboardEditView", function() {
    beforeEach(function() {
        this.model = backboneFixtures.dashboardConfig({
            userId: "2",
            modules: ["SiteSnapshot", "ProjectCardList"],
            availableModules: ["ActivityStream"]
        });
        this.view = new chorus.views.UserDashboardEditView({model: this.model});
    });

    describe("#render", function() {
        beforeEach(function() {
            this.view.render();
        });

        it("displays the list of selected modules", function() {
            var selected = this.model.get("modules");
            _.each(selected, function(name) {
                expect(this.view.$(".selected_modules li." + name)).toExist();
            }, this);
        });

        it("displays the list of available modules", function() {
            var available = this.model.get("availableModules");
            _.each(available, function(name) {
                expect(this.view.$(".available_modules li." + name)).toExist();
            }, this);
        });

        it("includes the desription with the module", function() {
            var selected = this.model.get("modules");
            var available = this.model.get("availableModules");
            var all = selected.concat(available);
            _.each(all, function(name) {
                var underscoredName = _.underscored(name);
                var prefix = "dashboard." + underscoredName + ".";
                expect(this.view.$("li." + name + " > .name")).toContainTranslation(prefix + "name");
                expect(this.view.$("li." + name + " > .module_description")).toContainTranslation(prefix + "description");
            }, this);
        });

        it("sets up the sortables", function() {
            spyOn($.fn, "sortable").and.callThrough();
            this.view.render();

            expect($.fn.sortable).toHaveBeenCalledOnSelector(".sortable");
            expect($.fn.sortable).toHaveBeenCalledWith({connectWith: ".sortable"});

            expect(this.view.$(".selected_modules ul")).toHaveClass("ui-sortable");
            expect(this.view.$(".available_modules ul")).toHaveClass("ui-sortable");
        });

        describe("submitting the changes", function() {
            beforeEach(function() {
                this.view.$("form").submit();
            });

            it("saves the dashboard config", function() {
                var json = this.server.lastCreateFor(this.model).json()["dashboard_config"];
                expect(json["modules"]).toEqual(["SiteSnapshot", "ProjectCardList"]);
            });

            context("when request is successful", function() {
                it("redirects to dashboard page", function() {
                    spyOn(chorus.router, "navigate");
                    this.server.completeCreateFor(this.view.model);
                    expect(chorus.router.navigate).toHaveBeenCalledWith("/");
                });
            });
        });

        context("cancelling", function() {
            beforeEach(function() {
                spyOn(this.view.$("form")[0], "submit");
                this.view.$("button.cancel").click();
            });

            it("does not submit the form", function() {
                expect(this.view.$("form")[0].submit).not.toHaveBeenCalled();
            });

            it("navigates back", function() {
                expect(window.history.back).toHaveBeenCalled();
            });
        });
    });
});
