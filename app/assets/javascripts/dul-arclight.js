Blacklight.onLoad(function () {
  /* =================== */
  /* BOOTSTRAP PLUGINS   */
  /* =================== */

  /* Bootstrap popovers out-of-the-box don't work on async-loaded DOM */
  /* elements, e.g. contextual tree nav, thus we have to trigger them */
  /* this way. */

  var popOverSettings = {
    placement: 'right',
    container: 'body',
    boundary: 'viewport',
    html: true,
    trigger: 'hover',
    selector: '[data-toggle="popover"]',
    content: function () {
      return $(this).data('content');
    }
  };

  $('body').popover(popOverSettings);

  $('#sidebar .sidebar-scroll-wrapper').scroll(function () {
    $('[data-toggle="popover"]').popover('hide');
  });

  $('body').tooltip({
    selector: '[data-toggle="tooltip"]'
  });

  /* Ensure all tooltips disappear after clicking the icon/label */
  $(document).on('click', 'label.toggle-bookmark', function (e) {
    $('.tooltip').hide();
  });

  /* Enable clicking in the collection info dropdown w/o closing it. E.g., to */
  /* select/copy a permalink or Aleph ID */
  $(document).on('click', '.dropdown-menu.collection-info-menu', function (e) {
    e.stopPropagation();
  });

  /* =================== */
  /* SEARCH BOX BEHAVIOR */
  /* =================== */

  /* Searching within a collection should not yield results */
  /* grouped by collection. */

  $('form.search-query-form').submit(() => {
    if ($('select#within_collection').val()) {
      $('input#group').remove();
    }
  });

  /* Fix autofocus for Firefox and Safari */
  $('.homepage').find('input#q').focus();


  /* Adding a click event to the Twitter Typeahead so that  */
  /* the form submits when the user clicks on a search suggestion. */

  $(document).on('typeahead:select', '.tt-input', function (e) {
    $('.search-query-form')[0].submit();
  });


  /* Do not display clear-search button when the page is first loaded. */
  if (!$('input#q').val()) {
    $('#clear-search').css('display', 'none');
  }

  /* If the input value has a length of at least 1, display the */
  /* clear-search button. */
  $('input#q').keyup(function () {
    inputValue = $('input#q').val().length;
    if (inputValue > 0) {
      $('#clear-search').css('display', 'inline');
    }
    /* If the user manually deletes the input value, hide the button. */
    if (inputValue == 0) {
      $('#clear-search').css('display', 'none');
    }
  });

  /* When the user clicks on the clear-search button, clear the value. This */
  /* behaves slightly different than a standard reset button, because it */
  /* clears the value even after the form has been submitted. */
  $('#clear-search').click(function() {
    // eslint-disable-next-line max-len
    // $('.tt-input').val(''); DCP2-485: ArcLight - Turn off predictive text - commented out this line
    $('input#q').val(''); // DCP2-485: ArcLight - Turn off predictive text - added this line
    $('#clear-search').css('display', 'none');
  });

  /* ================= */
  /* MASTHEAD BEHAVIOR */
  /* ================= */


  /* DUL masthead primary navigation menu toggle */
  $('a#full-menu-toggle').on('click', function (e) {
    e.preventDefault();

    $('#dul-masthead-region-megamenu').slideToggle();

    // toggle FA content
    var el = $('a#full-menu-toggle span.nav-icon');
    el.html(el.html() == '<i class="fas fa-bars"></i>' ? '<i class="fas fa-times"></i>' : '<i class="fas fa-bars"></i>');
  });


  /* ============== */
  /* Search Results */
  /* ============== */

  // Remove 'sr-only' class from applied search params label
  $('#appliedParams span.constraints-label').removeClass('sr-only');


  /* =========== */
  /* Context Nav */
  /* =========== */

  /* This set of functions deals with the sidebar drawer side fly-in. */
  /* The feature partially uses Bootstrap 4 modal functionality but */
  /* not entirely, so it needs a little help. */

  $(document).on('click', '.modal-backdrop', function (e) {
    $('#sidebar').modal('hide');
  });

  $('.sidebar-nav-toggle').click(function () {
    $('#sidebar').modal('toggle');
  });

  $('#sidebar').on('shown.bs.modal', function (event) {
    $('#sidebar-close').focus();
  });

  $('#sidebar').on('hidden.bs.modal', function (event) {
    $(this).show();
    $('.sidebar-nav-toggle').first().focus();
  });

  /* Clicking side-drawer sidebar links that lead to in-page anchors must */
  /* close the sidebar */
  $('#sidebar a[data-turbolinks="false"]').click(function () {
    $('#sidebar').modal('hide');
  });


  /* #facet-panel-collapse */

  // smooth scroll
  $('.smooth-scroll').click(function () {
    var sectionTo = $(this).attr('href');
    $('html, body').animate({
      scrollTop: $(sectionTo).offset().top
    }, 1500);
  });


  /* ========================= */
  /* Hide empty metadata boxes */
  /* ========================= */

  fadeOutContent('#document dl.al-metadata-section');

  function fadeOutContent(targetElement) {
    if (!$(targetElement + ':has(*)').length) {
      $(targetElement).fadeOut();
    }
  }


  /* ========================= */
  /* Augment truncation toggle */
  /* ========================= */

  var $pathsToTarget = '';
  $pathsToTarget += '#documents .responsiveTruncatorToggle';
  $pathsToTarget += ', ';
  $pathsToTarget += '#results-nav-and-constraints .responsiveTruncatorToggle';
  $pathsToTarget += ', ';
  $pathsToTarget += '#content .al-grouped-results .responsiveTruncatorToggle';

  updateAllTruncatedText = function () {
    $($pathsToTarget).text('show more').append(" <i class='fas fa-chevron-circle-down'></i>").wrapInner("<span class='btn-wrapper'></span>");
    $($pathsToTarget).addClass('showing-less');
  };

  toggleExpanded = function () {
    if ($($this).parent('.card-text').hasClass('expanded')) {
      $($this).parent('.card-text').removeClass('expanded');
    } else {
      $($this).parent('.card-text').addClass('expanded');
    }
  };

  toggleText = function () {
    if ($($this).hasClass('showing-less')) {
      $($this).removeClass('showing-less').addClass('showing-more');
      $($this).text('show less').append(" <i class='fas fa-chevron-circle-up'></i>").wrapInner("<span class='btn-wrapper'></span>");
    } else {
      $($this).removeClass('showing-more').addClass('showing-less');
      $($this).text('show more').append(" <i class='fas fa-chevron-circle-down'></i>").wrapInner("<span class='btn-wrapper'></span>");
    }
  };

  // initial page load
  updateAllTruncatedText();

  // click collection or card button
  $($pathsToTarget).click(function () {
    $this = this;
    toggleExpanded($this);
    toggleText($this);
  });

  $(window).bind('resize', function () {
    $('.responsiveTruncatorToggle').parent('.card-text').removeClass('expanded');

    updateAllTruncatedText();

    // need to do this again after binding resize?
    $('.responsiveTruncatorToggle').click(function () {
      $this = this;
      toggleExpanded($this);
      toggleText($this);
    });
  });


  // account for dynamically loaded content
  if ($('body').hasClass('blacklight-catalog-show')) {
    // wait for document placeholder content to go away
    var checkExistDocument = setInterval(function () {
      var placeholderPath = $('#document .al-hierarchy-placeholder').html();

      if (undefined === placeholderPath) {
        updateAllTruncatedText();

          // click series button
        $('#document #documents .responsiveTruncatorToggle').on('click', function () {
          $this = this;
          toggleExpanded($this);
          toggleText($this);
        });

        $(window).bind('resize', function () {
          updateAllTruncatedText();

            // need to do this again after binding resize?
          $('#document #documents .responsiveTruncatorToggle').on('click', function () {
            $this = this;
            toggleExpanded($this);
            toggleText($this);
          });
        });

        clearInterval(checkExistDocument);
      }
    }, 100);
  }


  /* ================================================ */
  /* Reload DUL masthead when turbolinks is triggered */
  /* Scroll to hash tag anchor after turbolinks load  */
  /* ================================================ */

  $(document).on('ready turbolinks:load', function () {
    loadMastHTML();
    scrollToHashTagAnchor();
  });

  loadMastHTML = function () {
    // console.log('turbolinks triggered!');

    var $DULmastheadURL = 'https://library.duke.edu/masthead/load-masthead.js.php?width=1820&amp;fixed=false&ajax_reload=true&div=true';

    $('#dul-masthead-filler').load($DULmastheadURL, function (response, status, xhr) {
      if (status == 'error') {
        console.log('There was an error loading external masthead html:');
        console.log(xhr.status + ' -- ' + xhr.statusText);
      }
    });
  };

  scrollToHashTagAnchor = function () {
    if (location.hash) {
      let el = document.querySelector(location.hash);
      if (el) { el.scrollIntoView(); }
    }
  };

  /* ================================================ */
  /* Add FA icons */
  /* ================================================ */

  $('#content #emailLink').html('<i class="fas fa-envelope"></i> Email Bookmarks');
});
