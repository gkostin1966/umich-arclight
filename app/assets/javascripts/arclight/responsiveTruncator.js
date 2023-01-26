/* Local DUL copy of a file from ArcLight core in order to fix a bug. */
/* Last checked for updates: ArcLight v0.4.0. */

/* See: */
/* https://github.com/projectblacklight/arclight/blob/master/vendor/assets/javascripts/responsiveTruncator.js */


/*
 * jQuery Responsive Truncator Plugin
 *
 * https://github.com/jkeck/responsiveTruncator
 *
 * VERSION 0.0.2
 *
* */
(function ($) {
  $.fn.responsiveTruncate = function (options) {
    var $this = this;
    $(window).bind('resize', function () {
      removeTruncation($this);
      addTruncation($this);
    });

    addTruncation($this);

    function addTruncation(el) {
      el.each(function () {
        if ($('.responsiveTruncate', $(this)).length == 0) {
          var parent = $(this);
          var fontSize = $(this).css('font-size');
          var lineHeight = $(this).css('line-height') ? $(this).css('line-height').replace('px', '') : Math.floor(parseInt(fontSize.replace('px', '')) * 1.5);
          var total_lines = Math.ceil(parent.height() / lineHeight);
          var settings = $.extend({
            lines: 3,
            height: 70,
            more: 'more',
            less: 'less'
          }, options);
          var truncate_height;
          if (settings.height) {
            truncate_height = settings.height;
          } else {
            // DUL CUSTOMIZATION: add Math.ceil to fix a height rounding issue impacting Firefox
            // See Jira ARC-333 & ArcLight issue #1027.
            // https://github.com/projectblacklight/arclight/issues/1027

            truncate_height = Math.ceil((lineHeight * settings.lines));
          }
          if (parent.height() > truncate_height) {
            var orig_content = parent.html();
            parent.html("<div style='height: " + truncate_height + "px; overflow: hidden; margin-top: .5em' class='responsiveTruncate'></div>");
            var truncate = $('.responsiveTruncate', parent);
            truncate.html(orig_content);
            truncate.after("<a class='responsiveTruncatorToggle' href='#'>" + settings.more + '</a>');
            var toggle_link = $('.responsiveTruncatorToggle', parent);
            toggle_link.click(function () {
              var text = toggle_link.text() == settings.more ? settings.less : settings.more;
              toggle_link.text(text);
              if (truncate.height() <= truncate_height) {
                truncate.css({ height: '100%' });
              } else {
                truncate.css({ height: truncate_height });
              }
              return false;
            });
          }
        }
      });
    }

    function removeTruncation(el) {
      el.each(function () {
        if ($('.responsiveTruncate', $(this)).length > 0) {
          $(this).html($('.responsiveTruncate', $(this)).html());
          $('.responsiveTruncatorToggle', $(this)).remove();
        }
      });
    }
  };
}(jQuery));
