/* globals $, window, document, FileReader, localStorage, alert */

/*
initialize the main page
- handle button clicks (import/export/hotkey stuff)
- handle clipboard paste
- handle errors
- load document from localStorage (fall back to plain in-memory datastructures)
- initialize objects (session, settings, etc.) with relevant divs
*/

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

import keyDefinitions from './keyDefinitions';
// load all definitions
require('./definitions/*.js', {mode: 'expand'});
// load all plugins
require('../../plugins/**/*.js', {mode: 'expand'});
import KeyBindings from './keyBindings';


const $keybindingsDiv = $('#keybindings');
const $settingsDiv = $('#settings');
const $modeDiv = $('#mode');

const docname = window.location.pathname.split('/')[1];

const changeStyle = theme => $('body').attr('id', theme);

async function create_session(doc, to_load) {

  //###################
  // Settings
  //###################

  const settings = new Settings(doc.store, {mainDiv: $settingsDiv});

  const theme = await settings.getSetting('theme');
  changeStyle(theme);
  $settingsDiv.find('.theme-selection').val(theme);
  $settingsDiv.find('.theme-selection').on('input', function(/*e*/) {
    const theme = this.value;
    settings.setSetting('theme', theme);
    return changeStyle(theme);
  });

  const showingKeyBindings = await settings.getSetting('showKeyBindings');
  $keybindingsDiv.toggleClass('active', showingKeyBindings);

  //###################
  // hotkeys and key bindings
  //###################

  const hotkey_settings = await settings.getSetting('hotkeys', {});
  const key_bindings = new KeyBindings(keyDefinitions, hotkey_settings);

  //###################
  // session
  //###################

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

  const session = new Session(doc, {
    bindings: key_bindings,
    settings,
    mainDiv: $('#view'),
    messageDiv: $('#message'),
    menuDiv: $('#menu'),
    viewRoot: viewRoot,
    cursorPath: cursorPath,
  });

  key_bindings.on('applied_hotkey_settings', function(hotkey_settings) {
    settings.setSetting('hotkeys', hotkey_settings);
    Render.renderHotkeysTable(key_bindings);
    return Render.renderModeTable(key_bindings, session.mode, $keybindingsDiv);
  });

  const render_mode_info = function(mode) {
    Render.renderModeTable(key_bindings, mode, $keybindingsDiv);
    return $modeDiv.text(Modes.getMode(mode).name);
  };

  render_mode_info(session.mode);
  session.on('modeChange', (oldmode, newmode) => render_mode_info(newmode)
  );

  session.on('toggleBindingsDiv', function() {
    $keybindingsDiv.toggleClass('active');
    doc.store.setSetting('showKeyBindings', $keybindingsDiv.hasClass('active'));
    return Render.renderModeTable(key_bindings, session.mode, $keybindingsDiv);
  });

  //###################
  // plugins
  //###################

  const pluginManager = new PluginsManager(session, $('#plugins'));
  let enabledPlugins = (await settings.getSetting('enabledPlugins')) || ['Marks'];
  if (typeof enabledPlugins.slice === 'undefined') { // for backwards compatibility
    enabledPlugins = Object.keys(enabledPlugins);
  }
  enabledPlugins.forEach((plugin_name) => pluginManager.enable(plugin_name));
  Render.renderPlugins(pluginManager);

  pluginManager.on('status', () => Render.renderPlugins(pluginManager));

  pluginManager.on('enabledPluginsChange', function(enabled) {
    settings.setSetting('enabledPlugins', enabled);
    Render.renderPlugins(pluginManager);
    Render.renderSession(session);
    // refresh hotkeys, if any new ones were added/removed
    Render.renderHotkeysTable(session.bindings);
    return Render.renderModeTable(session.bindings, session.mode, $keybindingsDiv);
  });

  //###################
  // load data
  //###################

  if (to_load !== null) {
    doc.load(to_load);
    // a bit hack.  without this, you can undo initial marks, for example
    session.reset_history();
    session.reset_jump_history();
  }

  //###################
  // prepare dom
  //###################

  // render when ready
  $(document).ready(function() {
    if (docname !== '') { document.title = `${docname} - Vimflowy`; }
    return Render.renderSession(session);
  });

  const key_handler = new KeyHandler(session, key_bindings);

  const key_emitter = new KeyEmitter();
  key_emitter.listen();
  key_emitter.on('keydown', (key) => {
    // NOTE: this is just a best guess... e.g. the mode could be wrong
    // problem is that we process asynchronously, but need to
    // return synchronously
    const handled = !!key_bindings.bindings[session.mode][key];

    // fire and forget
    key_handler.handleKey(key).then(() => {
      Render.renderSession(session);
    });
    return handled;
  });

  session.on('importFinished', () => Render.renderSession(session));

  // expose globals, for debugging
  window.Modes = Modes;
  window.session = session;
  window.key_handler = key_handler;
  window.key_emitter = key_emitter;
  window.key_bindings = key_bindings;

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
      Render.renderSession(session);
      session.save();
    });

    $('#settings-link').click(async function() {
      if (session.mode === Modes.modes.SETTINGS) {
        await session.setMode(Modes.modes.NORMAL);
      } else {
        await session.setMode(Modes.modes.SETTINGS);
      }
    });

    $('#settings-nav li').click(function(e) {
      const tab = $(e.target).data('tab');
      $settingsDiv.find('.tabs > li').removeClass('active');
      $settingsDiv.find('.tab-pane').removeClass('active');
      $settingsDiv.find(`.tabs > li[data-tab=${tab}]`).addClass('active');
      return $settingsDiv.find(`.tab-pane#${tab}`).addClass('active');
    });

    const load_file = function(filesDiv, cb) {
      const file = filesDiv.files[0];
      if (!file) {
        return cb('No file selected for import!');
      }
      session.showMessage('Reading in file...');
      const reader = new FileReader();
      reader.readAsText(file, 'UTF-8');
      reader.onload = function(evt) {
        const content = evt.target.result;
        return cb(null, content, file.name);
      };
      return reader.onerror = function(evt) {
        cb('Import failed due to file-reading issue');
        return logger.error('Import Error', evt);
      };
    };

    $('#hotkeys_import').click(() => {
      load_file($('#hotkeys_file_input')[0], function(err, content) {
        if (err) { return session.showMessage(err, {text_class: 'error'}); }
        let hotkey_settings;
        try {
          hotkey_settings = JSON.parse(content);
        } catch (e) {
          return session.showMessage(`Failed to parse JSON: ${e}`, {text_class: 'error'});
        }
        err = key_bindings.apply_hotkey_settings(hotkey_settings);
        if (err) {
          return session.showMessage(err, {text_class: 'error'});
        } else {
          return session.showMessage('Loaded new hotkey settings!', {text_class: 'success'});
        }
      });
    });

    $('#hotkeys_export').click(function() {
      const filename = 'vimflowy_hotkeys.json';
      const content = JSON.stringify(key_bindings.hotkeys, null, 2);
      utils.download_file(filename, 'application/json', content);
      return session.showMessage(`Downloaded hotkeys to ${filename}!`, {text_class: 'success'});
    });

    $('#hotkeys_default').click(function() {
      key_bindings.apply_default_hotkey_settings();
      return session.showMessage('Loaded defaults!', {text_class: 'success'});
    });

    $('#data_import').click(() => {
      load_file($('#import-file :file')[0], async (err, content, filename) => {
        if (err) { return session.showMessage(err, {text_class: 'error'}); }
        const mimetype = utils.mimetypeLookup(filename);
        if (await session.importContent(content, mimetype)) {
          session.showMessage('Imported!', {text_class: 'success'});
          await session.setMode(Modes.modes.NORMAL);
        } else {
          session.showMessage('Import failed due to parsing issue', {text_class: 'error'});
        }
      });
    });

    $('#data_export_json').click(() => session.exportFile('json'));
    $('#data_export_plain').click(() => session.exportFile('txt'));
  });

  return $(window).unload(() => session.exit());
};

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
