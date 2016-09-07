/* globals window, document, localStorage, alert */

/*
initialize the main page
- handle button clicks (import/export/hotkey stuff)
- handle clipboard paste
- handle errors
- load document from localStorage (fall back to plain in-memory datastructures)
- initialize objects (session, settings, etc.)
- handle rendering logic
*/

// TODO: use react more properly

import $ from 'jquery';
import React from 'react';
import ReactDOM from 'react-dom';

import 'font-awesome/css/font-awesome.css';
import '../css/utils.sass';
import '../css/index.sass';
import '../css/view.sass';
import '../css/themes/default.sass';
import '../css/themes/dark.sass';
import '../css/themes/solarized_dark.sass';
import '../css/themes/solarized_light.sass';

import * as constants from './constants';
import * as errors from './errors';
import * as utils from './utils';
import logger from './logger';

import * as Modes from './modes';
import KeyEmitter from './keyEmitter';
import KeyHandler from './keyHandler';
import * as DataStore from './datastore';
import Document from './document';
import Settings from './settings';
import { PluginsManager } from './plugins';
import Path from './path';
import Session from './session';
import * as Render from './render';

import SettingsMenu from './components/settings.jsx';

import keyDefinitions from './keyDefinitions';
// load actual definitions
import './definitions';
// load all plugins
import '../../plugins';
import KeyBindings from './keyBindings';

$(document).ready(function() {

  const getKeybindingsDiv = () => $('#keybindings');
  const getMessageDiv = () => $('#message');
  const getMainDiv = () => $('#view');

  const docname = window.location.pathname.split('/')[1];
  if (docname !== '') { document.title = `${docname} - Vimflowy`; }

  const changeStyle = theme => $('body').attr('id', theme);
  // const changeStyle = theme => $('body').removeClass().addClass(theme);

  async function create_session(doc, to_load) {
    const settings = new Settings(doc.store);

    // hotkeys and key bindings
    const initial_hotkey_settings = await settings.getSetting('hotkeys', {});
    const key_bindings = new KeyBindings(keyDefinitions, initial_hotkey_settings);

    // session
    if (!doc.hasChildren(doc.root.row)) {
      // HACKY: should load the actual data now, but since plugins aren't enabled...
      doc.load(constants.empty_data);
    }
    const viewRoot = Path.loadFromAncestry(doc.store.getLastViewRoot());
    // TODO: if we ever support multi-user case, ensure last view root is valid
    let cursorPath;
    if (viewRoot.isRoot()) {
      cursorPath = doc.getChildren(viewRoot)[0];
    } else {
      cursorPath = viewRoot;
    }

    function getLineHeight() {
      const line_height = $('.node-text').height() || 21;
      errors.assert(line_height > 0);
      return line_height;
    }

    function download_file(filename, mimetype, content) {
      const exportDiv = $('#export');
      exportDiv.attr('download', filename);
      exportDiv.attr('href', `data: ${mimetype};charset=utf-8,${encodeURIComponent(content)}`);
      exportDiv[0].click();
      exportDiv.attr('download', null);
      return exportDiv.attr('href', null);
    }

    const session = new Session(doc, {
      bindings: key_bindings,
      settings,
      viewRoot: viewRoot,
      cursorPath: cursorPath,
      showMessage: (() => {
        let messageDivTimeout = null;
        return (message, options = {}) => {
          const $messageDiv = getMessageDiv();
          if (options.time === undefined) { options.time = 5000; }
          logger.info(`Showing message: ${message}`);
          if ($messageDiv) {
            clearTimeout(messageDivTimeout);

            $messageDiv.text(message);
            if (options.text_class) {
              $messageDiv.addClass(`text-${options.text_class}`);
            }

            messageDivTimeout = setTimeout(() => {
              $messageDiv.text('');
              return $messageDiv.removeClass();
            }, options.time);
          }
        };
      })(),
      getVisiblePaths: async () => {
        const paths = [];
        $.makeArray($('.bullet')).forEach((bullet) => {
          if (!utils.isScrolledIntoView($(bullet), getMainDiv())) {
            return;
          }
          if ($(bullet).hasClass('fa-clone')) {
            return;
          }
          // NOTE: can't use $(x).data
          // http://stackoverflow.com/questions/25876274/jquery-data-not-working
          const ancestry = $(bullet).attr('data-ancestry');
          if (!ancestry) { // as far as i know, this only happens because of menu mode
            return;
          }
          const path = Path.loadFromAncestry(JSON.parse(ancestry));
          paths.push(path);
        });
        return paths;
      },
      toggleBindingsDiv: () => {
        const $keybindingsDiv = getKeybindingsDiv();
        $keybindingsDiv.toggleClass('active');
        doc.store.setSetting('showKeyBindings', $keybindingsDiv.hasClass('active'));
        return Render.renderModeTable(key_bindings, session.mode, $keybindingsDiv);
      },
      getLinesPerPage: () => {
        const line_height = getLineHeight();
        const page_height = $(document).height();
        return page_height / line_height;
      },
      downloadFile: (filename, mimetype, content) => {
        download_file(filename, mimetype, content);
      },
    });

    // load plugins

    const pluginManager = new PluginsManager(session);
    let enabledPlugins = (await settings.getSetting('enabledPlugins')) || ['Marks'];
    if (typeof enabledPlugins.slice === 'undefined') { // for backwards compatibility
      enabledPlugins = Object.keys(enabledPlugins);
    }
    enabledPlugins.forEach((plugin_name) => pluginManager.enable(plugin_name));

    // load data

    if (to_load !== null) {
      doc.load(to_load);
      // a bit hack.  without this, you can undo initial marks, for example
      session.reset_history();
      session.reset_jump_history();
    }

    const key_handler = new KeyHandler(session, key_bindings);

    const key_emitter = new KeyEmitter();

    // expose globals, for debugging
    window.Modes = Modes;
    window.session = session;
    window.key_handler = key_handler;
    window.key_emitter = key_emitter;
    window.key_bindings = key_bindings;

    const initialTheme = await settings.getSetting('theme');
    changeStyle(initialTheme);

    const renderProm = new Promise((resolve) => {
      ReactDOM.render(
        <div>
          {/* hack for firefox paste */}
          <div id="paste-hack" contentEditable="true" className="offscreen">
          </div>

          <div id="contents">
            <div id="menu" className="hidden"></div>
            <div id="view"></div>
            <div id="keybindings" className="theme-bg-secondary"></div>
          </div>

          <div id="settings" className="hidden theme-bg-primary">
            <SettingsMenu
              session={session}
              key_bindings={key_bindings}
              initialTheme={initialTheme}
              onThemeChange={(theme) => {
                settings.setSetting('theme', theme);
                changeStyle(theme);
              }}
              onExport={() => {
                const filename = 'vimflowy_hotkeys.json';
                const content = JSON.stringify(key_bindings.hotkeys, null, 2);
                download_file(filename, 'application/json', content);
                session.showMessage(`Downloaded hotkeys to ${filename}!`, {text_class: 'success'});
              }}
            />
          </div>

          <div id="bottom-bar" className="theme-bg-primary theme-trim"
               style={{ display: 'flex' }}
          >
            <a className="center theme-bg-secondary"
               onClick={async () => {
                 if (session.mode === Modes.modes.SETTINGS) {
                   await session.setMode(Modes.modes.NORMAL);
                 } else {
                   await session.setMode(Modes.modes.SETTINGS);
                 }
               }}
               style={{
                 flexBasis: 100, flexGrow: 0,
                 cursor: 'pointer', textDecoration: 'none'
               }}
            >
              <div id="settings-open">
                <span style={{marginRight:10}} className="fa fa-cog">
                </span>
                <span>Settings
                </span>
              </div>
              <div id="settings-close" className="hidden">
                <span style={{marginRight:10}} className="fa fa-arrow-left">
                </span>
                <span>
                  Back
                </span>
              </div>
            </a>
            <div id="message"
                 style={{flexBasis: 0, flexGrow: 1}}
            >
            </div>
            {/* should be wide enough to fit the words 'VISUAL LINE'*/}
            <div id="mode" className="center theme-bg-secondary"
                 style={{flexBasis: 80, flexGrow: 0}}
            >
            </div>
          </div>

          <a id="export" className="hidden"> </a>
        </div>
        ,
        $('#app')[0],
        resolve
      );
    });

    renderProm.then(async () => {
      const $settingsDiv = $('#settings');
      const $modeDiv = $('#mode');
      const $pluginsDiv = $('#plugins');
      const $menuDiv = $('#menu');
      const $mainDiv = $('#view');

      session.on('scroll', (numlines) => {
        const line_height = getLineHeight();
        utils.scrollDiv($mainDiv, line_height * numlines);
      });

      // load settings

      const showingKeyBindings = await settings.getSetting('showKeyBindings');
      getKeybindingsDiv().toggleClass('active', showingKeyBindings);

      session.on('importFinished', () => Render.renderSession(session, $mainDiv));

      function renderMain() {
        if (session.mode === Modes.modes.SEARCH) {
          Render.renderMenu(session.menu, $menuDiv[0]);
        } else {
          Render.renderSession(session, $mainDiv);
        }
      }

      key_emitter.listen();
      key_emitter.on('keydown', (key) => {
        // NOTE: this is just a best guess... e.g. the mode could be wrong
        // problem is that we process asynchronously, but need to
        // return synchronously
        const handled = !!key_bindings.bindings[session.mode][key];

        // fire and forget
        key_handler.handleKey(key).then(() => {
          renderMain();
        });
        return handled;
      });

      //###################
      // prepare dom
      //###################

      // render when ready
      $(document).ready(function() {
        // render mode
        const render_mode_info = function(mode) {
          Render.renderModeTable(key_bindings, mode, getKeybindingsDiv());
          return $modeDiv.text(Modes.getMode(mode).name);
        };

        render_mode_info(session.mode);
        session.on('modeChange', (oldmode, newmode) => {
          render_mode_info(newmode);

          $settingsDiv.toggleClass('hidden', newmode !== Modes.modes.SETTINGS);
          $('#settings-open').toggleClass('hidden', newmode === Modes.modes.SETTINGS);
          $('#settings-close').toggleClass('hidden', newmode !== Modes.modes.SETTINGS);

          $menuDiv.toggleClass('hidden', newmode !== Modes.modes.SEARCH);
          // NOTE: maybe showing mainDiv would be nice?
          // removing this line mostly works
          $mainDiv.toggleClass('hidden', newmode === Modes.modes.SEARCH);
        });

        const render_hotkey_settings = (hotkey_settings) => {
          settings.setSetting('hotkeys', hotkey_settings);
          Render.renderHotkeysTable(key_bindings);
          return Render.renderModeTable(key_bindings, session.mode, getKeybindingsDiv());
        };
        render_hotkey_settings(initial_hotkey_settings);
        key_bindings.on('applied_hotkey_settings', render_hotkey_settings);

        Render.renderPlugins($pluginsDiv, pluginManager);
        pluginManager.on('status', () => Render.renderPlugins($pluginsDiv, pluginManager));

        pluginManager.on('enabledPluginsChange', function(enabled) {
          settings.setSetting('enabledPlugins', enabled);
          Render.renderPlugins($pluginsDiv, pluginManager);
          Render.renderSession(session, $mainDiv);
          // refresh hotkeys, if any new ones were added/removed
          Render.renderHotkeysTable(session.bindings);
          return Render.renderModeTable(session.bindings, session.mode, getKeybindingsDiv());
        });

        return renderMain();
      });

      $(document).ready(function() {
        // needed for safari
        const $pasteHack = $('#paste-hack');
        $pasteHack.focus();
        $(document).on('click', function() {
          // if settings menu is up, we don't want to blur (the dropdowns need focus)
          if ($settingsDiv.hasClass('hidden')) {
            // if user is trying to copy, we don't want to blur
            if (!window.getSelection().toString()) {
              return $pasteHack.focus();
            }
          }
        });

        $(document).on('paste', async (e) => {
          e.preventDefault();
          const text = (e.originalEvent || e).clipboardData.getData('text/plain');
          // TODO: deal with this better when there are multiple lines
          // maybe put in insert mode?
          const lines = text.split('\n');
          for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (i !== 0) {
              await session.newLineAtCursor();
            }
            const chars = line.split('');
            session.addCharsAtCursor(chars);
          }
          Render.renderSession(session, $mainDiv);
          session.save();
        });
      });
    });

    return $(window).on('unload', () => session.exit());
  }

  let datastore;
  let doc;

  if (typeof localStorage !== 'undefined' && localStorage !== null) {
    datastore = new DataStore.LocalStorageLazy(docname);
    doc = new Document(datastore, docname);

    let to_load = null;
    if (datastore.getLastSave() === 0) {
      to_load = constants.default_data;
    }

    create_session(doc, to_load);
  } else {
    alert('You need local storage support for data to be persisted!');
    datastore = new DataStore.InMemory;
    doc = new Document(datastore, docname);
    create_session(doc, constants.default_data);
  }

  window.onerror = function(msg, url, line, col, err) {
    logger.error(`Caught error: '${msg}' from  ${url}:${line}`);
    if (err !== undefined) {
      logger.error('Error: ', err, err.stack);
    }

    if (err instanceof errors.DataPoisoned) {
      // no need to alert, already alerted
      return;
    }

    return alert(`
      An error was caught.  Please refresh the page to avoid weird state. \n\n
      Please help out vimflowy and report the bug!
      Simply open the javascript console, save the log as debug information,
      and send it to wuthefwasthat@gmail.com with a brief description of what happened.
      \n\n
      ERROR:\n\n
      ${msg}\n\n
      ${err}\n\n
      ${err.stack}
    `
    );
  };
});
