import debounce from 'discourse/lib/debounce';

export default Ember.Controller.extend({
  needs: ["application"],
  queryParams: ["current_period", "order", "asc", "name"],
  current_period: "first_quarterly",
  order: "likes_received",
  asc: null,
  name: "",

  showTimeRead: Ember.computed.equal("current_period", "all"),

  _setName: debounce(function() {
    this.set("name", this.get("nameInput"));
  }, 500).observes("nameInput"),

  _showFooter: function() {
    this.set("controllers.application.showFooter", !this.get("model.canLoadMore"));
  }.observes("model.canLoadMore"),

  actions: {
    loadMore() {
      this.get("model").loadMore();
    }
  }
});
