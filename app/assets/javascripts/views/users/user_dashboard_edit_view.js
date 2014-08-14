chorus.views.UserDashboardEditView = chorus.views.Base.extend({
    constructorName: "UserDashboardEditView",
    templateName: "user/dashboard_edit",
    events: {
        "submit form": "save",
        "click button.cancel": "goBack"
    },

    postRender: function() {
        this.$(".sortable").sortable({ connectWith: ".sortable" });
    },

    save: function(e) {
        e && e.preventDefault();

        this.model.set("modules", this.fieldValues());
        this.model.save({}, {
            success: function() { chorus.router.navigate('/'); }
        });
    },

    fieldValues: function() {
        return _.map(this.$(".selected_modules li"), function(el) {
            return el.id;
        });
    },

    goBack:function () {
        window.history.back();
    },

    additionalContext: function() {
        return {
            modules: this.mapModules(this.model.get("modules")),
            availableModules: this.mapModules(this.model.get("availableModules"))
        };
    },

    mapModules: function(ary) {
        return _.map(ary, function(name) {
            return {
                classKey: name,
                nameKey: "dashboard." + _.underscored(name)  + ".name",
                descKey: "dashboard." + _.underscored(name)  + ".description"
            };
        });
    }
});
