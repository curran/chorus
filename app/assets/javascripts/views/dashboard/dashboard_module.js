chorus.views.DashboardModule = chorus.views.Base.extend({
    constructorName: "DashboardModuleView",
    templateName:"dashboard/module",

    additionalContext: function () {
        return {
            content: this.options.content
        };
    }

});

_.each([
    "Module1",
    "Module2",
    "Module3"
], function(moduleName) {
    chorus.views["Dashboard" + moduleName] = chorus.views.DashboardModule;
});
