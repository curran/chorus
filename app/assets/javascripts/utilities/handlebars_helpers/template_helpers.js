chorus.handlebarsHelpers.template = {
    renderTemplate: function(templateName, context) {
        return new Handlebars.SafeString(window.HandlebarsTemplates[templateName](context));
    },

    formControls:function(submitText, cancelText) {
        if(cancelText && cancelText.hash) {
            cancelText = "actions.cancel";
        }
        return Handlebars.helpers.renderTemplate("components/form_controls", { submitText: submitText, cancelText: cancelText});
    },

    formControlsWithDisabledSubmit: function(submitText, cancelText) {
        if(cancelText && cancelText.hash) {
            cancelText = "actions.cancel";
        }
        return Handlebars.helpers.renderTemplate("components/form_controls", { submitText: submitText, cancelText: cancelText, disabled: true});
    },

    infoBlock: function(infoTranslation) {
        return Handlebars.helpers.renderTemplate("components/info_block", {info: infoTranslation});
    },

    renderTemplateIf: function(conditional, templateName, context) {
        if (conditional) {
            return Handlebars.helpers.renderTemplate(templateName, context);
        } else {
            return "";
        }
    },

    renderErrors: function(serverErrors) {
        var output = ["<ul>"];
        var errorMessages = chorus.Mixins.ServerErrors.serverErrorMessages.call({serverErrors: serverErrors});

        _.each(errorMessages, function(message) {
            output.push("<li>" + Handlebars.Utils.escapeExpression(message) + "</li>");
        });

        output.push("</ul>");
        return new Handlebars.SafeString(output.join(""));
    },

    spanFor: function(text, attributes) {
        return new Handlebars.SafeString($("<span></span>").text(text).attr(attributes || {}).outerHtml());
    },

    uploadWidgetFor: function(propertyName) {
        return Handlebars.helpers.renderTemplate("components/upload_widget", { propertyName: propertyName });
    },

    hdfsDataSourceFields: function(context) {
        return Handlebars.helpers.renderTemplate("data_sources/hdfs_data_source_fields", context || {});
    },

    hdfsVersionsSelect: function(selectOne) {
        selectOne = selectOne === undefined ? true : selectOne;
        return Handlebars.helpers.renderTemplate("data_sources/hdfs_versions_select", {
            hdfsVersions: chorus.models.Config.instance().get("hdfsVersions"),
            selectOne: selectOne
        });
    },

    timeZonesSelect: function () {
        return Handlebars.helpers.renderTemplate('time_zone_selector', {
            zones: chorus.models.Config.instance().get("timeZones")
        });
    },

    dbDataSourceFields: function(context) {
        return Handlebars.helpers.renderTemplate("data_sources/db_data_source_fields", context || {});
    },

    jdbcDataSourceFields: function(context) {
        return Handlebars.helpers.renderTemplate("data_sources/jdbc_data_source_fields", context || {});
    },

    workflowResultLink: function (jobTaskResult) {
        var result = new chorus.models.WorkFlowResult({workfileId: jobTaskResult.payloadId, id: jobTaskResult.payloadResultId});
        return Handlebars.helpers.renderTemplate("workflow_result_link", { link: result.showUrl(), name: result.name() });
    },

    modelNamesList: function(collection) {
        function appendLast(name) { return ", and " + name; }

        var list = "";
        var comma = ", ";
        var names = collection.map(function(m) { return _.result(m, "name"); });
        var length = names.length;

        switch (length) {
            case 0:
                list = "";
                break;
            case 1:
                list = names[0];
                break;
            case 2:
                list = names.join(" and ");
                break;
            case 3:
                var last = names.pop();
                list = names.join(comma) + appendLast(last);
                break;
            default:
                list = names.slice(0,2).join(comma) + appendLast(length - 2 + " others");
                break;
        }

        return new Handlebars.SafeString(list);
    },

    dashboardModuleList: function(modules, className, translationKey) {
        var ctx = {
            modules: modules,
            className: className,
            translationKey: translationKey
        };
        return Handlebars.helpers.renderTemplate("user/dashboard_edit_list", ctx);
    }
};

_.each(chorus.handlebarsHelpers.template, function(helper, name) {
    Handlebars.registerHelper(name, helper);
});
