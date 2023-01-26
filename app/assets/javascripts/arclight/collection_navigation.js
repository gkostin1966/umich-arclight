// Copy of ArcLight core JS for overriding behavior.
// Last checked for updates: ArcLight v0.3.2.

// Added data.arclight.directparent for listing only
// the child components of the current component rather
// than all descendants. Added per_page option so different
// paginated AJAX-loaded results can include different
// numbers of results loaded per page (e.g., all online vs.
// child components).

// Created a customized placeholder for child component section
// that more closely resembles the content.

// See
// https://github.com/projectblacklight/arclight/blob/master/app/assets/javascripts/arclight/collection_navigation.js

(function (global) {
  var CollectionNavigation;

  CollectionNavigation = {
    init: function (el, page = 1) {
      var $el = $(el);
      var data = $el.data();

      // DUL CUSTOMIZATION: Show a gridded placeholder that resembles
      // the child component layout. CSS is used to show only the number
      // of placeholder rows needed for the particular content, and
      // add light animation.

      const $markup = $('<div class="al-hierarchy-placeholder"></div>');
      const elementMarkup = '<div class="row placeholder-row">' +
        '<div class="col-8"><p></p></div>' +
        '<div class="col-3"><p></p></div>' +
        '<div class="col-1"><p></p></div>' +
        '</div>';
      const placeholder = Array(21).join(elementMarkup);
      // NOTE: <section> element used instead of <div> or <p> to not throw off
      // :nth-of-type calculations in CSS.
      $markup.append('<section id="sortAndPerPage" class="sort-pagination clearfix">\
                      <strong class="page-links">Loading...</strong>\
                      </section>');
      $markup.append(placeholder);
      $el.html($markup);

      $.ajax({
        url: data.arclight.path,
        data: {
          'f[component_level_isim][]': data.arclight.level,
          'f[has_online_content_ssim][]': data.arclight.access,
          'f[collection_sim][]': data.arclight.name,
          'f[parent_ssim][]': data.arclight.parent,
          'f[parent_ssi][]': data.arclight.directparent,
          page: page,
          search_field: data.arclight.search_field,
          view: data.arclight.view,
          per_page: data.arclight.per_page
        }
      }).done(function (response) {
        var resp = $.parseHTML(response);
        var $doc = $(resp);
        var showDocs = $doc.find('article.document');
        var newDocs = $doc.find('#documents');
        var sortPerPage = $doc.find('#sortAndPerPage');
        var pageEntries = sortPerPage.find('.page-entries');
        var numberEntries = parseInt(pageEntries.find('strong').last().text().replace(/,/g, ''), 10);

        // Hide these until we re-enable in the future
        sortPerPage.find('.result-type-group').hide();
        sortPerPage.find('.search-widgets').hide();

        if (!isNaN(numberEntries)) {
          $('[data-arclight-online-content-tab-count]').html(
            $(
              '<span class="badge badge-pill badge-secondary al-online-content-badge">'
                + numberEntries
                + '<span class="sr-only">components</span></span>'
            )
          );
        }

        sortPerPage.find('a').on('click', function (e) {
          var pages = [];
          var $target = $(e.target);
          e.preventDefault();
          // DUL CUSTOMIZATION: use &page to not pick up per_page parameter
          pages = /&page=(\d+)&/.exec($target.attr('href'));

          if (pages) {
            CollectionNavigation.init($el, pages[1]);
          } else {
            // Case where the "first" page
            CollectionNavigation.init($el);
          }
        });

        $el.hide().html('').append(sortPerPage).append(newDocs)
          .fadeIn(500);
        if (showDocs.length > 0) {
          $el.trigger('navigation.contains.elements');
        }
        Blacklight.doBookmarkToggleBehavior();

        // DUL CUSTOMIZATION: 'deep' clone sortAndPerPage and append ID
        if ($(sortPerPage).text().indexOf('Previous') > -1) {
          $(sortPerPage).clone(true).prop('id', 'sortAndPerPageBottom').insertAfter('#documents');
          // fix duplicate IDs
          $('#sortAndPerPageBottom #sort-dropdown').prop('id', 'sort-dropdown-bottom');
          $('#sortAndPerPageBottom #per_page-dropdown').prop('id', 'per_page-dropdown-bottom');
          $('#sortAndPerPageBottom #Layer_1').prop('id', 'Layer_1-bottom');
        }
      });
    }
  };

  global.CollectionNavigation = CollectionNavigation;
}(this));

Blacklight.onLoad(function () {
  'use strict';

  $('.al-contents').each(function (i, element) {
    CollectionNavigation.init(element); // eslint-disable-line no-undef
  });

  $('.al-contents').on('navigation.contains.elements', function (e) {
    var toEnable = $('[data-hierarchy-enable-me]');
    var srOnly = $('h2[data-sr-enable-me]');
    toEnable.removeClass('disabled');
    toEnable.text(srOnly.data('hasContents'));
    srOnly.text(srOnly.data('hasContents'));

    $(e.target).find('.collapse').on('show.bs.collapse', function (ee) {
      var $newTarget = $(ee.target);
      $newTarget.find('.al-contents').each(function (i, element) {
        CollectionNavigation.init(element); // eslint-disable-line no-undef
        // Turn off additional ajax requests on show
        $newTarget.off('show.bs.collapse');
      });
    });
  });
});
