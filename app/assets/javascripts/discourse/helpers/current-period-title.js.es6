const CURRENT_TITLE_SUBS = {
  first_quarterly: 'first_quarter',
  second_quarterly: 'second_quarter',
  third_quarterly: 'third_quarter',
  fourth_quarterly: 'fourth_quarter',
};

// TODO @sushil10018: Place the date time properly in details.
export default Ember.Handlebars.makeBoundHelper(function (current_period, options) {
  const title = I18n.t('filters.top.' + (CURRENT_TITLE_SUBS[current_period] || 'this_week'));
  if (options.hash.showDateRange) {
    var dateString = "";
    switch(current_period) {
      case 'first_quarterly':
        dateString = moment().subtract(1, 'year').format(I18n.t('dates.long_with_year_no_time')) + " - " + moment().format(I18n.t('dates.long_with_year_no_time'));
        break;
      case 'second_quarterly':
        dateString = moment().subtract(3, 'month').format(I18n.t('dates.long_no_year_no_time')) + " - " + moment().format(I18n.t('dates.long_no_year_no_time'));
        break;
      case 'third_quarterly':
        dateString = moment().subtract(1, 'week').format(I18n.t('dates.long_no_year_no_time')) + " - " + moment().format(I18n.t('dates.long_no_year_no_time'));
        break;
      case 'fourth_quarterly':
        dateString = moment().subtract(1, 'month').format(I18n.t('dates.long_no_year_no_time')) + " - " + moment().format(I18n.t('dates.long_no_year_no_time'));
        break;
      case 'daily':
        dateString = moment().format(I18n.t('dates.full_no_year_no_time'));
        break;
      case 'test':
        dateString = moment().format(I18n.t('dates.full_no_year_no_time'));
        break;
    }
    return new Handlebars.SafeString(title + " <span class='top-date-string'>" + dateString + "</span>");
  } else {
    return new Handlebars.SafeString(title);
  }
});
