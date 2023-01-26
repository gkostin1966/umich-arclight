// Copy of ArcLight core JS for overriding behavior.
// Last checked for updates: ArcLight v0.4.0.
//
// See:
// https://github.com/projectblacklight/arclight/blob/master/app/assets/javascripts/arclight/context_navigation.js

class NavigationDocument {
  constructor(el) {
    this.el = $(el);
  }

  get id() {
    return this.el.find('[data-document-id]').data().documentId;
  }

  setAsHighlighted() {
    this.el.find('li.al-collection-context').addClass('al-hierarchy-highlight');
  }

  makeCollapsible() {
    this.el.find('li.al-collection-context').addClass('collapsible');
  }

  collapse() {
    this.el.find('li.al-collection-context').addClass('collapsed');
  }

  render() {
    return this.el.html();
  }
}

/**
 * Models the "Expand"/"Collapse" button, and provides an onClick event handler
 * for the jQuery element
 * @class
 */
class ExpandButton {
  /**
   * This retrieves the <li> elements which are hidden/rendered in response to
   *   clicking the <button> element
   * @param {jQuery} $li - the <button> element
   * @return {jQuery} - a jQuery object containing the targeted <li>
   */
  findCollapsibleSiblings() {
    // DUL CUSTOMIZATION: Account for our change wrapping the <button> in an <li>
    // for a11y: Add another .parent() & then target .al-collection-context
    // class specifically (so the button li isn't considered a sibling).
    const $siblings = this.$el.parent().parent().children('li.al-collection-context.collapsible');
    return $siblings;
  }

  /**
   * This adds a "collapsed" class to all of the <li> children, as well as
   *   updates the text for the <button> element
   * @param {Event} event - the event propagated in response to clicking on the
   *   <button> element
   */
  handleClick() {
    const $targeted = this.findCollapsibleSiblings();

    $targeted.toggleClass('collapsed');
    this.$el.toggleClass('collapsed');

    const containerText = this.$el.hasClass('collapsed') ? this.collapseText : this.expandText;
    this.$el.text(containerText);
  }

  /**
   * @constructor
   */
  constructor(data) {
    this.collapseText = data.collapse;
    this.expandText = data.expand;

    this.$el = $(`<button class="my-3 btn btn-secondary btn-sm">${this.expandText}</button>`);

    this.handleClick = this.handleClick.bind(this);
    this.$el.click(this.handleClick);
  }
}

/**
 * Models the placeholder display elements for content loading from AJAX
 *   requests
 * @class
 */
class Placeholder {
  /*
   * Builds the element set which contains the placeholder markup
   *   classes
   */
  /* eslint-disable class-methods-use-this */
  buildElement() {
    // DUL CUSTOMIZATION: Use only one wrapper div; repeat the placeholders in it.
    // Bump from 3 to 6 so placeholder pattern repeats 5x. This makes it easier to
    // conditionally show fewer lines using CSS.
    const $markup = $('<div class="al-hierarchy-placeholder"></div>');
    const elementMarkup = '' +
      '<p class="col-9"></p>' +
      '<p class="col-6"></p>' +
      '<p class="col-10"></p>' +
      '<p class="col-3"></p>';
    const placeholder = Array(6).join(elementMarkup);
    $markup.append(placeholder);
    return $markup;
  }
  /* eslint-enable class-methods-use-this */

  /*
   * @constructor
   */
  constructor() {
    this.$el = this.buildElement();
  }
}

class ContextNavigation {
  constructor(el, originalParents = null, originalDocument = null) {
    this.el = $(el);
    this.data = this.el.data();
    this.parentLi = this.el.parent();
    this.eadid = this.data.arclight.eadid;
    this.originalParents = originalParents; // let originalParents stay null
    this.originalDocument = originalDocument || this.data.arclight.originalDocument;
    this.ul = $('<ul class="al-context-nav-parent"></ul>');
  }

  // Gets the targetId to select, based off of parents and current level
  get targetId() {
    if (this.originalParents && this.originalParents[this.data.arclight.level]) {
      // DUL CUSTOMIZATION: Account for custom id with underscore
      return `${this.eadid}_${this.originalParents[this.data.arclight.level]}`;
    }
    return this.data.arclight.originalDocument;
  }

  get requestParent() {
    // Cases where you're viewing a component page (use its ancestor trail)...
    if (this.originalParents && this.originalParents[this.data.arclight.level - 1]) {
      return this.originalParents[this.data.arclight.level - 1];
    }
    // Cases where there are no parents provided...
    //   1) when on a top-level collection page
    //   2) when +/- gets clicked

    // DUL CUSTOMIZATION: Account for DUL component IDs which have "_" between
    // the eadid & component ref.
    return this.data.arclight.originalDocument.replace(this.eadid + '_', '');
  }

  getData() {
    const that = this;
    // Add a placeholder so flashes of text are not as significant
    const placeholder = new Placeholder();

    // DUL CUSTOMIZATION: If there are a lot of children to load, add a
    // gentle message about the potential delay.
    var childrencount = parseInt(this.el.parent().data('childrencount'));
    if (childrencount > 200) {
      this.el.prepend('<div class="load-warning">\
        <strong> <i class="fas fa-clock"></i> Loading ' +
        childrencount.toLocaleString() +
        ' items</strong><br/>' +
        'This might take a while.</div>');
    }

    this.el.after(placeholder.$el);
    $.ajax({
      url: this.data.arclight.path,
      data: {
        'f[component_level_isim][]': this.data.arclight.level,
        'f[has_online_content_ssim][]': this.data.arclight.access,
        'f[collection_sim][]': this.data.arclight.name,
        'f[parent_ssi][]': this.requestParent,
        search_field: this.data.arclight.search_field,
        original_parents: this.data.arclight.originalParents,
        original_document: this.originalDocument,
        view: 'collection_context'
      }
    }).done((response) => that.updateView(response));
  }

  /**
   * Constructs a <ul> container element with an ElementButton instance appended
   * within it
   * @returns {jQuery}
   */
  buildExpandList() {
    const $ul = $('<ul></ul>');
    $ul.addClass('pl-0');
    $ul.addClass('prev-siblings');
    const button = new ExpandButton(this.data);

    // DUL CUSTOMIZATION: wrap the <button> in an <li> for a11y & adjust the script;
    // <button> not allowed as child of <ul>.
    const $li = $('<li></li>');
    $li.append(button.$el);
    $ul.append($li);
    return $ul;
  }

  /**
   * Highlights the <li> element for the current Document and appends <li> the
   *   sibling documents for a given Document element
   * @param {NavigationDocument[]} newDocs - the NavigationDocument objects for
   *   each resulting Solr Document
   * @param {number} originalDocumentIndex
   */
  updateSiblings(newDocs, originalDocumentIndex) {
    newDocs[originalDocumentIndex].setAsHighlighted();

    // Hide all but the first previous sibling
    const prevSiblingDocs = newDocs.slice(0, originalDocumentIndex);
    let nextSiblingDocs = [];

    if (prevSiblingDocs.length > 1 && originalDocumentIndex > 0) {
      const hiddenPrevSiblingDocs = prevSiblingDocs.slice(0, -1);
      hiddenPrevSiblingDocs.forEach(siblingDoc => {
        siblingDoc.makeCollapsible();
        siblingDoc.collapse();
      });

      const prevSiblingList = this.buildExpandList();
      const renderedPrevSiblingItems = prevSiblingDocs.map(doc => doc.render()).join('');

      prevSiblingList.append(renderedPrevSiblingItems);
      this.ul.append(prevSiblingList);

      nextSiblingDocs = newDocs.slice(originalDocumentIndex);
    } else {
      nextSiblingDocs = newDocs;
    }

    const renderedNextSiblingItems = nextSiblingDocs.map(newDoc => newDoc.render()).join('');

    // Insert the rendered sibling documents before the <li> elements
    this.ul.append(renderedNextSiblingItems);
    this.el.html(this.ul);
  }

  /**
   * Inserts <li> elements for parents (e. g. components or collections) for the
   *   current Document and appends <li> for each of these
   * @param {NavigationDocument[]} newDocs - the NavigationDocument objects for
   *   each resulting Solr Document
   */
  updateParents(newDocs) {
    const that = this;
    // Case where this is a parent list and needs to be filed correctly
    //
    // Otherwise, retrieve the parent...
    let newDocIndex = newDocs.findIndex(doc => doc.id === this.targetId);

    if (newDocIndex === -1) {
      const renderedDocs = newDocs.map(newDoc => newDoc.render()).join('');
      this.ul.append(renderedDocs);
      this.el.html(this.ul);
      return;
    }
    // Update the docs before the item
    // Retrieves the documents up to and including the "new document"
    const beforeDocs = newDocs.slice(0, newDocIndex);
    let prevParentList = null;
    let renderedBeforeDocs;
    if (beforeDocs.length > 1) {
      beforeDocs.forEach(function (parentDoc) {
        parentDoc.makeCollapsible();
        parentDoc.collapse();
      });
      renderedBeforeDocs = beforeDocs.map(newDoc => newDoc.render()).join('');
      prevParentList = this.buildExpandList();
      prevParentList.append(renderedBeforeDocs);
    } else {
      renderedBeforeDocs = beforeDocs.map(newDoc => newDoc.render()).join('');
    }

    // Silly but works for now
    this.ul.append(prevParentList || renderedBeforeDocs);

    let itemDoc = newDocs.slice(newDocIndex, newDocIndex + 1);
    let renderedItemDoc = itemDoc.map(doc => doc.render()).join('');

    // Update the item
    const $itemDoc = $(renderedItemDoc);
    this.ul.append($itemDoc);

    // Update the docs after the item
    const afterDocs = newDocs.slice(newDocIndex + 1, newDocs.length);
    const renderedAfterDocs = afterDocs.map(newDoc => newDoc.render()).join('');

    // Insert the documents after the current
    this.ul.append(renderedAfterDocs);
    this.el.html(this.ul);

    // Initialize additional things
    $itemDoc.find('.context-navigator').each(function (i, e) {
      const contextNavigation = new ContextNavigation(
        e, that.originalParents, that.originalDocument
      );
      contextNavigation.getData();
    });
  }

  /**
   * This updates the elements in the View DOM using an AJAX response containing
   *   the HTML of a server-rendered View template.
   * It is this which is primarily used to populate the <ul> element with
   *   children for the navigation context, containing <li> elements for
   *   collections, components, and containers.
   * @param {string} response - the AJAX response body
   */
  updateView(response) {
    const that = this;
    var resp = $.parseHTML(response);
    var $doc = $(resp);
    var newDocs = $doc.find('#documents')
      .find('article')
      .toArray().map(el => new NavigationDocument(el));

    // See if the original document is located in the returned documents
    const originalDocumentIndex = newDocs
      .findIndex(doc => doc.id === that.originalDocument);
    that.parentLi.find('.al-hierarchy-placeholder').remove();

    // If the original document in the results, update it. If not update with a
    // more complex procedure
    if (originalDocumentIndex !== -1) {
      this.updateSiblings(newDocs, originalDocumentIndex);
    } else {
      this.updateParents(
        newDocs,
        that.data.arclight.originalParents,
        that.data.arclight.parent,
        that.parentLi
      );
    }
    this.el.parent().data('resolved', true);
    this.addListenersForPlusMinus();
    this.enablebuttons();

    Blacklight.doBookmarkToggleBehavior();

    // DUL CUSTOMIZATION: Run client-side a11y patches once the dynamic content
    // has loaded. See assets/javascripts/accessibility-patches.js.
    applyAccessibilityPatches();

    this.el.trigger('navigation.contains.elements');
  }

  // eslint-disable-next-line class-methods-use-this
  enablebuttons() {
    var toEnable = $('[data-hierarchy-enable-me]');
    var srOnly = $('h2[data-sr-enable-me]');
    toEnable.removeClass('disabled');
    toEnable.text(srOnly.data('hasContents'));
    srOnly.text(srOnly.data('hasContents'));
  }

  addListenersForPlusMinus() {
    const that = this;
    this.ul.find('.al-toggle-view-children').on('click', (e) => {
      e.preventDefault();
      const targetArea = $($(e.currentTarget).attr('href'));
      if (!targetArea.data('resolved') == true) {
        targetArea.find('.context-navigator').each((i, ee) => {
          const contextNavigation = new ContextNavigation(
            // Send null for originalParents. We want to disregard the original
            // component's ancestor trail and instead use the current ID as the
            // parent in the query to populate the navigator.
            ee, null, that.originalDocument
          );
          contextNavigation.getData();
        });
      }
    });
  }
}

/**
 * Integrate the behavior into the DOM using the Blacklight#onLoad callback
 *
 */
Blacklight.onLoad(function () {
  $('.context-navigator').each(function (i, e) {
    const contextNavigation = new ContextNavigation(
        e, $(this).data('arclight').originalParents, $(this).data('arclight').originalDocument
      );
    contextNavigation.getData();
  });
});
