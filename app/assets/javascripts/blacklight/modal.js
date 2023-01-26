// from https://github.com/ghosh/micromodal/blob/master/src/index.js
// adapted from cozy-sun-bear modals
const FOCUSABLE_ELEMENTS = [
  'a[href]',
  'area[href]',
  'input:not([disabled]):not([type="hidden"])',
  'select:not([disabled])',
  'textarea:not([disabled])',
  'button:not([disabled])',
  'iframe',
  'object',
  'embed',
  '[contenteditable]',
  '[tabindex]:not([tabindex^="-"])'
];

const ACTIONABLE_ELEMENTS = [
  'a[href]',
  'area[href]',
  'input[type="submit"]:not([disabled])',
  'button:not([disabled])'
].join(',');

const getFocusableNodes = function (modalEl) {
  const nodes = $(modalEl).get(0).querySelectorAll(FOCUSABLE_ELEMENTS);
  const focusable = [];
  nodes.forEach((node) => {
    if ($(node).is(':visible')) { focusable.push(node); }
  });
  return focusable;
};

let ACTIVE_MODALS = [];

$(document).on('shown.bs.modal', function (e) {
  // loaded.blacklight.blacklight-modal may sometimes be fired first
  let modalEl = e.target;
  let index = ACTIVE_MODALS.indexOf(modalEl);
  if (index < 0) {
    index = ACTIVE_MODALS.push(modalEl);
    index -= 1;
  }
  if (index > 0) {
    $(ACTIVE_MODALS[0]).modal('hide');
  }
  $(modalEl).find('button.close').focus();
});

$(document).on('hide.bs.modal', function (e) {
  let modalEl = e.target;
  let index = ACTIVE_MODALS.indexOf(modalEl);
  if (index > -1) {
    ACTIVE_MODALS.splice(index, 1);
  }
});

let debugInterval; let debugLastActive;
let debugActive = function () {
  if (debugInterval) {
    clearInterval(debugInterval);
    debugInterval = null;
    return;
  }
  setInterval(() => {
    if (debugLastActive != document.activeElement) {
      debugLastActive = document.activeElement;
      console.log('::', debugLastActive);
    }
  }, 1000);
};

$(document).on('loaded.blacklight.blacklight-modal', function (e) {
  // if (!$activeModal) { $activeModal = $(e.target); }
  let modalEl = e.target;
  let index = ACTIVE_MODALS.indexOf(modalEl);
  if (index < 0) {
    index = ACTIVE_MODALS.push(modalEl);
    index -= 1;
  }
  if (index != 0) { return; }

  let $activeModal = $(modalEl);

  let $possibleItem = $activeModal.find('button.close');
  let lastActiveItem = $activeModal.data('lastActive');
  if (lastActiveItem && lastActiveItem.hasAttribute('rel')) {
    let rel = lastActiveItem.rel;
    $possibleItem = $activeModal.find(`a[rel="${rel}"]:visible`);
    if (!$possibleItem.length) {
      let expr = `a[rel="${rel == 'next' ? 'prev' : 'next'}"]:visible`;
      $possibleItem = $activeModal.find(expr);
    }
  }
  $possibleItem.focus();
  $activeModal.data('lastActive', $possibleItem.get(0));
});

$(document).on('keydown', function (e) {
  const KEY_TAB = 9;

  // the activeModal _should_ be the first modal in the stack
  let modalEl = ACTIVE_MODALS[0];

  if (!modalEl) { return; }
  let focusableNodes = getFocusableNodes(modalEl);
  if (focusableNodes.length == 0) { return; }

  const focusedItemIndex = focusableNodes.indexOf(document.activeElement);
  switch (e.keyCode) {
    case KEY_TAB:

      let delta = e.shiftKey ? -1 : 1;
      let nextFocusedItem = document.activeElement;

      let nextFocusedItemIndex = focusableNodes.indexOf(nextFocusedItem);
      nextFocusedItemIndex += delta;
      if (nextFocusedItemIndex == focusableNodes.length) {
        nextFocusedItemIndex = 0;
      } else if (nextFocusedItemIndex < 0) {
        nextFocusedItemIndex = focusableNodes.length - 1;
      }
      nextFocusedItem = focusableNodes[nextFocusedItemIndex];

      nextFocusedItem.focus();
      $(modalEl).data('lastActive', nextFocusedItem);
      e.preventDefault();

      break;
    default:
      break;
  } // end switch
});
