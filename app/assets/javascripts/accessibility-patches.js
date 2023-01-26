/* ============================================================ */
/* Accessibility: Apply some band-aids on a11y issues.          */
/* NOTE: These changes fix some issues client-side that can't   */
/* easily be addressed otherwise. Blacklight.onLoad DOM         */
/* modifications do not work for elements added dynamically,    */
/* e.g., context tree navigation or child component nav, so the */
/* applyAccessibilityPatches() function must be added to each   */
/* AJAX done callback.
/*                                                              */
/* These mods should be revisited whenever newer versions of    */
/* the platforms are available/incorporated into ArcLight. This */
/* code should be removed once issues are resolved upstream.    */
/* ============================================================ */

function applyAccessibilityPatches() {
  /* ---------------------------------- */
  /* Area: typeahead search box         */
  /* ---------------------------------- */
  /* Issue: missing ARIA label.
  /* Platform: Blacklight */
  /* Version fixed in: (not fixed) */
  /* https://github.com/projectblacklight/blacklight/blob/master/lib/generators/blacklight/assets_generator.rb#L9 */
  /* We may need to use https://github.com/corejavascript/typeahead.js instead of the */
  /* twitter-typeahead-rails ruby gem that Blacklight includes. That gem has not been */
  /* updated for years; in the meantime the “corejavascript” fork of typeahead.js has */
  /* evolved to address several accessibility issues. */

  $('input.tt-hint').attr('aria-label', 'Search');

  /* ---------------------------------- */
  /* Area: search results pagination UI */
  /* ---------------------------------- */
  /* Issue: ARIA role "region" is not allowed for a <nav> element.
  /* Platform: Blacklight */
  /* Version fixed in: (not fixed) */
  /* https://github.com/projectblacklight/blacklight/blob/master/app/views/catalog/_results_pagination.html.erb#L4-L6 */

  $('nav[role="region"]').attr('role', 'navigation');


  /* ---------------------------------- */
  /* Area: Bookmark Checkboxes          */
  /* ---------------------------------- */
  /* Issue: bookmark checkboxes get cloned in the UI whenever there's an AJAX load,  */
  /* e.g., for context tree loading. This creates multiples of the same ID and makes */
  /* the ARIA labeling broken/invalid. This likely has something to do with          */
  /* Blacklight.doBookmarkToggleBehavior(); */
  /* Platform: ArcLight */
  /* Version fixed in: TBD */
  /* For now, we'll just remove all but the last one when this happens. */

  $('div.toggle-bookmark:not(:last-of-type)').remove();

  /* Issue: in grouped search results (index) view, if the top-level collection appears */
  /* within the top 3 results, its bookmark checkbox/label are duplicates of those same */
  /* elements in the group header box, thus invalid/inaccessible. */
  /* As a remedy, we append "_group" to these ids and the elements that reference them. */

  /* Platform: DUL-ArcLight (core doesn't have checkboxes in grouped view) */
  /* Version fixed in: TBD */

  $('.group-doc-actions').find("label[id^='bookmark_toggle_']").each(function () {
    $(this).attr('id', $(this).attr('id') + '_group');
    $(this).text('Collection ' + $(this).text());
  });
  $('.group-doc-actions').find("form[aria-labelledby^='bookmark_toggle_']").each(function () {
    $(this).attr('aria-labelledby', $(this).attr('aria-labelledby') + '_group');
  });
  $('.group-doc-actions').find("label[for^='toggle-bookmark_']").each(function () {
    $(this).attr('for', $(this).attr('for') + '_group');
  });
  $('.group-doc-actions').find("input[id^='toggle-bookmark_']").each(function () {
    $(this).attr('id', $(this).attr('id') + '_group');
  });


  /* ---------------------------------- */
  /* Area: Grouped Results Wrapper      */
  /* ---------------------------------- */
  /* Issue: keyboard nav link to "Skip to First Result" needs a #documents    */
  /* id when in grouped view for search results, else that link goes nowhere. */
  /* https://github.com/projectblacklight/arclight/blob/master/app/views/catalog/_group.html.erb#L2 */
  /* Platform: ArcLight */
  /* Version fixed in: TBD */

  $('div.al-grouped-results').attr('id', 'documents');


  /* ---------------------------------- */
  /* Area: Component Tree Navigation    */
  /* ---------------------------------- */
  /* Issue: we have ul > ul nesting; and need ul > li > ul for accessibility */

  $('ul.prev-siblings').each(function () {
    if (!$(this).parent().is('li')) {
      $(this).wrap('<li></li>');
    }
  });

  /* ---------------------------------- */
  /* Area: RTL language support         */
  /* ---------------------------------- */
  /* Issue: when a block of text is in a RTL language it should align right & read */
  /* right-to-left. Setting dir="auto" plus the CSS rule "text-align: start" seems */
  /* to accomplish this, setting the direction and alignment based on the language */
  /* of the first character used in the block. For now we can try this as a        */
  /* client-side DOM modification and limit it to <p> & <dd> elements. */

  $('p, dd').each(function () {
    $(this).attr('dir', 'auto');
  });
}

Blacklight.onLoad(function () {
  applyAccessibilityPatches();
});
