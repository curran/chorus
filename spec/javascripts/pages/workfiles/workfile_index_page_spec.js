describe("chorus.pages.WorkfileIndexPage", function() {
    beforeEach(function() {
        this.workspace = backboneFixtures.workspace();
        this.model = backboneFixtures.workfile.sql({workspace: {id: this.workspace.id}});
        spyOn(chorus.views.WorkfileSidebar, 'buildFor').andCallThrough();
        this.page = new chorus.pages.WorkfileIndexPage(this.workspace.id);
    });

    it("has a helpId", function() {
        expect(this.page.helpId).toBe("workfiles");
    });

    describe("#setup", function() {
        it("fetches the model", function() {
            var theUrl = "/workspaces/" + this.model.workspace().id;
            expect(_.any(this.server.requests, function(req) {
                return req.url.trim() === theUrl;
            })).toBeTruthy();
        });

        it("sets the workspace id, for prioritizing search", function() {
            expect(this.page.workspaceId.toString()).toBe(this.workspace.get("id"));
        });

        it("defaults to alphabetical sorting ascending", function() {
            expect(this.page.collection.order).toBe("fileName");
        });

        it("defaults to all files", function() {
            expect(this.page.collection.fileType).toBe("");
        });

        it("fetches the first page of the collection", function() {
            expect(this.page.collection).toHaveBeenFetched();
        });

        it("goes to 404 when the workspace fetch fails", function() {
            spyOn(Backbone.history, "loadUrl");
            this.server.lastFetchFor(this.page.workspace).failNotFound();
            expect(Backbone.history.loadUrl).toHaveBeenCalledWith("/invalidRoute");
        });

        it("passes the multiSelect option to the list content details", function() {
            expect(this.page.mainContent.contentDetails.options.multiSelect).toBeTruthy();
            expect(this.page.multiSelectSidebarMenu).toBeTruthy();
        });

        it("passes the workspaceIdForTagLink option as listItemOptions to the main content options", function() {
            expect(this.page.mainContent.content.options.listItemOptions.workspaceIdForTagLink).toBe(this.workspace.id);
        });
    });

    describe("when the workfile:selected event is triggered on the list view", function() {
        beforeEach(function() {
            this.server.completeFetchFor(this.workspace);
            this.page.render();
            chorus.PageEvents.trigger("workfile:selected", this.model);
        });

        it("sets the model of the page", function() {
            expect(this.page.model).toBe(this.model);
        });

        it('instantiates the sidebar view', function() {
            expect(this.page.sidebar).toBeDefined();
            expect(chorus.views.WorkfileSidebar.buildFor).toHaveBeenCalled();
            expect(this.page.$("#sidebar .sidebar_content.primary")).not.toBeEmpty();
        });

        describe("when workfile:selected event is triggered and there is already a sidebar", function() {
            beforeEach(function() {
                this.oldSidebar = this.page.sidebar;
                spyOn(this.page.sidebar, 'teardown');
                chorus.PageEvents.trigger("workfile:selected", this.model);
            });

            it("tears down the old sidebar", function() {
                expect(this.oldSidebar.teardown).toHaveBeenCalled();
            });
        });
    });

    describe("when the workspace and workfile collection fetches completes", function() {
        beforeEach(function() {
            this.server.completeFetchFor(this.workspace);
            this.server.completeFetchFor(this.page.collection, backboneFixtures.workfileSet());
        });


        itBehavesLike.aPageWithPrimaryActions([
            {name: 'import_workfile', target: chorus.dialogs.WorkfilesImport},
            {name: 'create_sql_workfile', target: chorus.dialogs.WorkfilesSqlNew}
        ]);

        describe("when the user can create workflows", function () {
            beforeEach(function () {
                spyOn(this.page.workspace, 'currentUserCanCreateWorkFlows').andReturn(true);
                this.page.render();
            });

            itBehavesLike.aPageWithPrimaryActions([
                {name: 'import_workfile', target: chorus.dialogs.WorkfilesImport},
                {name: 'create_sql_workfile', target: chorus.dialogs.WorkfilesSqlNew},
                {name: 'create_workflow', target: chorus.dialogs.WorkFlowNew}
            ]);
        });

        describe("when the user cannot update the workspace", function () {
            beforeEach(function () {
                spyOn(this.page.workspace, 'canUpdate').andReturn(false);
                this.page.render();
            });

            itBehavesLike.aPageWithPrimaryActions([]);
        });

        it("has a titlebar", function() {
            expect(this.page.$(".page_sub_header")).toContainText(this.workspace.name());
        });

        it("shows the page title", function() {
            expect(this.page.$('.content_header h1').text().trim()).toEqual(t("workfiles.title"));
        });

        itBehavesLike.aPageWithMultiSelect();

        describe("search", function() {
            beforeEach(function() {
                this.page.$("input.search").val("foo").trigger("keyup");
            });

            it("shows the Loading text in the count span", function() {
                expect($(this.page.$(".count"))).toContainTranslation("loading");
            });

            it("re-fetches the collection with the search parameters", function() {
                expect(this.server.lastFetch().url).toContainQueryParams({namePattern: "foo"});
            });

            context("when the fetch completes", function() {
                beforeEach(function() {
                    spyOn(this.page.mainContent, "render").andCallThrough();
                    spyOn(this.page.mainContent.content, "render").andCallThrough();
                    spyOn(this.page.mainContent.contentFooter, "render").andCallThrough();
                    spyOn(this.page.mainContent.contentDetails, "render").andCallThrough();
                    spyOn(this.page.mainContent.contentDetails, "updatePagination").andCallThrough();
                    this.server.completeFetchFor(this.page.collection);
                });

                it("updates the header, footer, and body", function() {
                    expect(this.page.mainContent.content.render).toHaveBeenCalled();
                    expect(this.page.mainContent.contentFooter.render).toHaveBeenCalled();
                    expect(this.page.mainContent.contentDetails.updatePagination).toHaveBeenCalled();
                });

                it("does not re-render the page or body", function() {
                    expect(this.page.mainContent.render).not.toHaveBeenCalled();
                    expect(this.page.mainContent.contentDetails.render).not.toHaveBeenCalled();
                });
                it("shows the Loading text in the count span", function() {
                    expect($(this.page.$(".count"))).not.toMatchTranslation("loading");
                });
            });
        });
    });

    describe("menus", function() {
        beforeEach(function() {
            this.server.completeFetchFor(this.workspace);
            this.server.completeFetchFor(this.page.collection);
        });

        describe("filtering", function() {
            beforeEach(function() {
                this.page.collection.fileType = undefined;
                spyOn(this.page.collection, "fetch");
            });

            it("has options for filtering", function() {
                expect(this.page.$("ul[data-event=filter] li[data-type=]")).toExist();
                expect(this.page.$("ul[data-event=filter] li[data-type=SQL]")).toExist();
                expect(this.page.$("ul[data-event=filter] li[data-type=CODE]")).toExist();
                expect(this.page.$("ul[data-event=filter] li[data-type=TEXT]")).toExist();
                expect(this.page.$("ul[data-event=filter] li[data-type=IMAGE]")).toExist();
                expect(this.page.$("ul[data-event=filter] li[data-type=OTHER]")).toExist();
            });

            it("can filter the list by 'all'", function() {
                this.page.$("li[data-type=] a").click();
                expect(this.page.collection.attributes.fileType).toBe("");
                expect(this.page.collection.fetch).toHaveBeenCalled();
            });

            it("can filter the list by 'SQL'", function() {
                this.page.$("li[data-type=SQL] a").click();
                expect(this.page.collection.attributes.fileType).toBe("SQL");
                expect(this.page.collection.fetch).toHaveBeenCalled();
            });

            context("when workflows are enabled", function () {
                beforeEach(function () {
                    spyOn(chorus.models.Config.instance().license(), "workflowEnabled").andReturn(true);
                    this.page = new chorus.pages.WorkfileIndexPage(this.workspace.id);
                    this.server.completeFetchFor(this.workspace);
                    this.server.completeFetchFor(this.page.collection);
                    spyOn(this.page.collection, "fetch");
                });

                it("can filter the list by 'WORK_FLOW'", function() {
                    this.page.$("li[data-type=WORK_FLOW] a").click();
                    expect(this.page.collection.attributes.fileType).toBe("WORK_FLOW");
                    expect(this.page.collection.fetch).toHaveBeenCalled();
                });
            });

            it("can filter the list by 'CODE'", function() {
                this.page.$("li[data-type=CODE] a").click();
                expect(this.page.collection.attributes.fileType).toBe("CODE");
                expect(this.page.collection.fetch).toHaveBeenCalled();
            });

            it("can filter the list by 'TEXT'", function() {
                this.page.$("li[data-type=TEXT] a").click();
                expect(this.page.collection.attributes.fileType).toBe("TEXT");
                expect(this.page.collection.fetch).toHaveBeenCalled();
            });

            it("can filter the list by 'IMAGE'", function() {
                this.page.$("li[data-type=IMAGE] a").click();
                expect(this.page.collection.attributes.fileType).toBe("IMAGE");
                expect(this.page.collection.fetch).toHaveBeenCalled();
            });

            it("can filter the list by 'OTHER'", function() {
                this.page.$("li[data-type=OTHER] a").click();
                expect(this.page.collection.attributes.fileType).toBe("OTHER");
                expect(this.page.collection.fetch).toHaveBeenCalled();
            });
        });

        describe("sorting", function() {
            beforeEach(function() {
                this.page.collection.order = undefined;
                spyOn(this.page.collection, "fetch");
            });

            it("has options for sorting", function() {
                expect(this.page.$("ul[data-event=sort] li[data-type=alpha]")).toExist();
                expect(this.page.$("ul[data-event=sort] li[data-type=date]")).toExist();
            });

            it("can sort the list alphabetically ascending", function() {
                this.page.$("li[data-type=alpha] a").click();
                expect(this.page.collection.order).toBe("fileName");
                expect(this.page.collection.fetch).toHaveBeenCalled();
            });

            it("can sort the list by date (hopefully descending)", function() {
                this.page.$("li[data-type=date] a").click();
                expect(this.page.collection.order).toBe("userModifiedAt");
                expect(this.page.collection.fetch).toHaveBeenCalled();
            });
        });
    });

});
