# ![Vimflowy](/static/images/vimflowy-32.png?raw=true) Vimflowy

[![Join Gitter chat](https://badges.gitter.im/WuTheFWasThat/vimflowy.svg)](https://gitter.im/WuTheFWasThat/vimflowy)
[![Build Status](https://travis-ci.org/WuTheFWasThat/vimflowy.svg?branch=master)](https://travis-ci.org/WuTheFWasThat/vimflowy)

This is a productivity tool which draws great inspiration from workflowy and vim.

Try it out!
- [online] (https://vimflowy.bitballoon.com)
- [local/dev](CONTRIBUTING.md)

(Video coming eventually...)

## FEATURES ##

- Workflowy features
  - tree-like outlining
  - collapsing and zooming into bullets
  - basic text formatting, strike through task completion
- Vim features
  - (configurable) vim keybindings
  - modal editing
  - session history (undo, moving through jump history)
  - repeats, macros
- Extras
  - data import/export
  - loads data lazily (good for big documents)
  - search (not like vim's)
  - cloning (bullets with multiple parents)
  - different visual themes
- Plugins system (see [plugins.md](docs/plugins.md))
  - marks (not like vim's)
  - easy-motion for moving between bullets quickly
  - time-tracking

## LIMITATIONS ##

- Currently, you can only edit from one tab at a time.
  There will likely never be collaboration features.
- There are [known inconsistencies with vim](docs/vim_inconsistencies.md)
- Tested mostly in recent Chrome and Firefox.  You may need a relatively modern browser.
- Currently essentially non-functional on mobile

## DATA STORAGE ##

Vimflowy is entirely local, and uses localStorage.
So each browser would have its own Vimflowy document.
Since data is local, offline editing is supported.
If you're going to have a very large document, use a browser with large localStorage limits (Firefox, for example).

Remote data storage is in an experimental stage and will soon be supported.
Feel free to contact us if you wish to try it out.

## NOTES FOR DEVELOPERS ##

Contributions are very welcome!
See [CONTRIBUTING.md](CONTRIBUTING.md) if you're interested

The [chrome app](https://chrome.google.com/webstore/detail/vimflowy/dkdhbejgjplkmbiglmjobppakgmiimei) exists but will no longer be maintained.
[Chrome apps are getting essentially deprecated](https://blog.chromium.org/2016/08/from-chrome-apps-to-web.html).

### LICENSE ###

MIT: https://wuthefwasthat.mit-license.org/
