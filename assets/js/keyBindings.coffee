# imports
if module?
  global._ = require('lodash')

  global.utils = require('./utils.coffee')
  global.Modes = require('./modes.coffee')
  global.errors = require('./errors.coffee')
  global.keyDefinitions = require('./keyDefinitions.coffee')
  global.Logger = require('./logger.coffee')

###
Terminology:
      key       - a key corresponds to a keypress, including modifiers/special keys
      command   - a command is a semantic event.  each command has a string name, and a definition (see keyDefinitions)
      mode      - same as vim's notion of modes.  each mode determines the set of possible commands, and a new set of bindings
      mode type - there are two mode types: insert-like and normal-like.  Each mode falls into precisely one of these two categories.
                  'insert-like' describes modes in which typing characters inserts the characters.
                  Thus the only keys configurable as commands are those with modifiers.
                  'normal-like' describes modes in which the user is not typing, and all keys are potential commands.

The Keybindings class is primarily responsible for dealing with hotkeys
Given a hotkey mapping, it combines it with key definitions to create a bindings dictionary,
also performing some validation on the hotkeys.
Concretely, it exposes 2 main objects:
      hotkeys:
          a 2-layered mapping.  For each mode type and command name, contains a list of keys
          this is the object the user can configure
      bindings:
          another 2-layer mapping.  For each mode and relevant key, maps to the corresponding command's function
          this is the object used internally for handling keys (i.e. translating them to commands)
It also internally maintains
      _keyMaps:
          a 2-layer mapping similar to hotkeys.  For each mode and command name, a list of keys.
          Used for rendering the hotkeys table
          besides translating the mode types into each mode, keyMaps differs from hotkeys by handles some quirky behavior,
          such as making the DELETE_CHAR command always act like DELETE in visual/visual_line modes

###

((exports) ->
  MODES = Modes.modes
  NORMAL_MODE_TYPE = Modes.NORMAL_MODE_TYPE
  INSERT_MODE_TYPE = Modes.INSERT_MODE_TYPE
  MODE_TYPES = Modes.types

  class KeyBindings
    # takes key definitions and keyMappings, and combines them to key bindings
    getBindings = (definitions, keyMap) ->
      bindings = {}
      for name, v of definitions
        if name == 'MOTION'
          keys = ['MOTION']
        else if (name of keyMap)
          keys = keyMap[name]
        else
          continue

        v = _.cloneDeep v
        v.name = name

        if typeof v.definition == 'object'
          [err, sub_bindings] = getBindings v.definition, keyMap
          if err
            return [err, null]
          else
            v.definition= sub_bindings

        for key in keys
          if key of bindings
            return ["Duplicate binding on key #{key}", bindings]
          bindings[key] = v
      return [null, bindings]

    constructor: (@settings, options = {}) ->
      # a mapping from commands to keys
      @_keyMaps = null
      # a recursive mapping from keys to commands
      @bindings = null


      hotkey_settings = @settings.getSetting 'hotkeys'
      err = @apply_hotkey_settings hotkey_settings

      if err
        Logger.logger.error "Failed to apply saved hotkeys #{hotkey_settings}"
        Logger.logger.error err
        do @apply_default_hotkey_settings

      @modebindingsDiv = options.modebindingsDiv

    render_hotkeys: () ->
      if $? # TODO: pass this in as an argument
        $('#hotkey-edit-normal').empty().append(
          $('<div>').addClass('tooltip').text(NORMAL_MODE_TYPE).attr('title', MODE_TYPES[NORMAL_MODE_TYPE].description)
        ).append(
          @buildTable @hotkeys[NORMAL_MODE_TYPE], (_.extend.apply @, (_.cloneDeep keyDefinitions.actions[mode] for mode in MODE_TYPES[NORMAL_MODE_TYPE].modes))
        )

        $('#hotkey-edit-insert').empty().append(
          $('<div>').addClass('tooltip').text(INSERT_MODE_TYPE).attr('title', MODE_TYPES[INSERT_MODE_TYPE].description)
        ).append(
          @buildTable @hotkeys[INSERT_MODE_TYPE], (_.extend.apply @, (_.cloneDeep keyDefinitions.actions[mode] for mode in MODE_TYPES[INSERT_MODE_TYPE].modes))
        )

    # tries to apply new hotkey settings, returning an error if there was one
    apply_hotkey_settings: (hotkey_settings) ->
      # merge hotkey settings into default hotkeys (in case default hotkeys has some new things)
      hotkeys = {}
      for mode_type of MODE_TYPES
        hotkeys[mode_type] = _.extend({}, keyDefinitions.defaultHotkeys[mode_type], hotkey_settings[mode_type] or {})

      # for each mode, get key mapping for that particular mode - a mapping from command to set of keys
      keyMaps = {}
      for mode_type, mode_type_obj of MODE_TYPES
        for mode in mode_type_obj.modes
          modeKeyMap = {}
          for command in keyDefinitions.commands[mode]
            modeKeyMap[command] = hotkeys[mode_type][command].slice()
          keyMaps[mode] = modeKeyMap

      bindings = {}
      for mode_name, mode of MODES
        [err, mode_bindings] = getBindings keyDefinitions.actions[mode], keyMaps[mode]
        if err then return "Error getting bindings for #{mode_name}: #{err}"
        bindings[mode] = mode_bindings

      motion_bindings = {}
      for mode_name, mode of MODES
        [err, mode_bindings] = getBindings keyDefinitions.motions, keyMaps[mode]
        if err then return "Error getting motion bindings for #{mode_name}: #{err}"
        motion_bindings[mode] = mode_bindings

      @hotkeys = hotkeys
      @bindings = bindings
      @motion_bindings = motion_bindings
      @_keyMaps = keyMaps

      do @render_hotkeys
      return null

    save_settings: (hotkey_settings) ->
      @settings.setSetting 'hotkeys', hotkey_settings

    # apply default hotkeys
    apply_default_hotkey_settings: () ->
        err = @apply_hotkey_settings {}
        errors.assert_equals err, null, "Failed to apply default hotkeys"
        @save_settings {}

    # build table to visualize hotkeys
    buildTable: (keyMap, actions, helpMenu) ->
      buildTableContents = (bindings, onto, recursed=false) ->
        for k,v of bindings
          if k == 'MOTION'
            if recursed
              keys = ['<MOTION>']
            else
              continue
          else
            keys = keyMap[k]
            if not keys
              continue

          if keys.length == 0 and helpMenu
            continue

          row = $('<tr>')

          # row.append $('<td>').text keys[0]
          row.append $('<td>').text keys.join(' OR ')

          display_cell = $('<td>').css('width', '100%').html v.description
          if typeof v.definition == 'object'
            buildTableContents v.definition, display_cell, true
          row.append display_cell

          onto.append row

      tables = $('<div>')

      for [label, definitions] in [['Actions', actions], ['Motions', keyDefinitions.motions]]
        tables.append($('<h5>').text(label).css('margin', '5px 10px'))
        table = $('<table>').addClass('keybindings-table theme-bg-secondary')
        buildTableContents definitions, table
        tables.append(table)

      return tables

    renderModeTable: (mode) ->
      if not @modebindingsDiv
        return
      if not (@settings.getSetting 'showKeyBindings')
        return

      table = @buildTable @_keyMaps[mode], keyDefinitions.actions[mode], true
      @modebindingsDiv.empty().append(table)

    # TODO getBindings: (mode) -> return @bindings[mode]

  module?.exports = KeyBindings
  window?.KeyBindings = KeyBindings
)()
