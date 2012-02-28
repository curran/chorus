chorus.views.WorkfileListSidebar = chorus.views.Sidebar.extend({
    className:"workfile_list_sidebar",
    subviews:{
        '.activities':'activityList'
    },

    setup:function () {
        this.bind("workfile:selected", this.setWorkfile, this);
    },

    setWorkfile:function (workfile) {
        this.workfile = workfile;
        if (this.workfile) {
            this.collection = this.workfile.activities();
            this.bindings.add(this.collection, "reset", this.render);
            this.collection.fetch();

            this.bindings.add(this.collection, "changed", this.render);
            this.bindings.add(this.workfile, "changed", this.render);

            this.activityList = new chorus.views.ActivityList({
                collection:this.collection,
                additionalClass:"sidebar",
                displayStyle:['without_object', 'without_workspace']
            });

            this.activityList.bind("content:changed", this.recalculateScrolling, this)

        } else {
            delete this.collection;
            delete this.activityList;
        }

        this.render();
    },

    additionalContext:function () {
        var ctx = { canUpdate: this.model && this.model.canUpdate() , hideAddNoteLink: this.options.hideAddNoteLink };
        if (this.workfile) {
            var modifier = this.workfile.modifier();
            var attributes = _.extend({}, this.workfile.attributes);
            attributes.updatedBy = modifier.displayShortName();
            attributes.modifierUrl = modifier.showUrl();
            attributes.downloadUrl = this.workfile.downloadUrl();
            ctx.workfile = attributes;
        }

        return ctx;
    }
});
