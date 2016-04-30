_ = require 'lodash'

utils = require './utils.coffee'
Modes = require './modes.coffee'
Logger = require './logger.coffee'
errors = require './errors.coffee'
EventEmitter = require './eventEmitter.coffee'

PLUGIN_SCHEMA = {
  title: "Plugin metadata schema"
  type: "object"
  required: [ 'name' ]
  properties: {
    name: {
      description: "Name of the plugin"
      pattern: "^[A-Za-z0-9_ ]{2,64}$"
      type: "string"
    }
    version: {
      description: "Version of the plugin"
      type: "number"
      default: 1
      minimum: 1
    }
    author: {
      description: "Author of the plugin"
      type: "string"
      default: "Unknown"
    }
    description: {
      description: "Description of the plugin"
      type: "string"
    }
  }
}

# global set of registered plugins
PLUGINS = {}

STATUSES = {
  UNREGISTERED: "Unregistered",
  DISABLING: "Disabling",
  ENABLING: "Enabling",
  DISABLED: "Disabled",
  ENABLED: "Enabled",
}


# class for exposing plugin API
class PluginApi
  constructor: (@session, @metadata, @pluginManager) ->
    @name = @metadata.name
    @document = @session.document
    @cursor = @session.cursor
    # TODO: Add subloggers and prefix all log messages with the plugin name
    @logger = Logger.logger

    @bindings = @session.bindings
    @definitions = @bindings.definitions
    @commands = @definitions.commands

  setData: (key, value) ->
    @document.store.setPluginData @name, key, value

  getData: (key, default_value=null) ->
    @document.store.getPluginData @name, key, default_value

  registerMode: (metadata) ->
    Modes.registerMode metadata
    do @session.bindings.init

  registerCommand: (metadata) ->
    cmd = @definitions.registerCommand metadata
    do @session.bindings.init
    return cmd

  registerMotion: (commands, motion, definition) ->
    @definitions.registerMotion commands, motion, definition
    do @session.bindings.init

  registerAction: (modes, commands, action, definition) ->
    @definitions.registerAction modes, commands, action, definition
    do @session.bindings.init

  panic: _.once () =>
    alert "Plugin '#{@name}' has encountered a major problem. Please report this problem to the plugin author."
    @pluginManager.disable @name

class PluginsManager extends EventEmitter

  constructor: (session, div) ->
    super
    @session = session
    @div = div
    @plugin_infos = {}

  get: (name) ->
    return @plugin_infos[name]

  getStatus: (name) ->
    if not PLUGINS[name]
      return STATUSES.UNREGISTERED
    @plugin_infos[name]?.status || STATUSES.DISABLED

  setStatus: (name, status) ->
    Logger.logger.info "Plugin #{name} status: #{status}"
    if not PLUGINS[name]?
      throw new Error "Plugin #{name} was not registered"
    plugin_info = @plugin_infos[name] || {}
    plugin_info.status = status
    @plugin_infos[name] = plugin_info
    @emit 'status'

  updateEnabledPlugins: () ->
    enabled = []
    for name of @plugin_infos
      if (@getStatus name) == STATUSES.ENABLED
        enabled.push name
    if @session.settings
      @session.settings.setSetting "enabledPlugins", enabled
    @emit 'enabledPluginsChange'

  enable: (name) ->
    status = @getStatus name
    if status == STATUSES.UNREGISTERED
      Logger.logger.error "No plugin registered as #{name}"
      PLUGINS[name] = null
      return
    if status == STATUSES.ENABLING
      throw new errors.GenericError("Already enabling plugin #{name}")
    if status == STATUSES.DISABLING
      throw new errors.GenericError("Still disabling plugin #{name}")
    if status == STATUSES.ENABLED
      throw new errors.GenericError("Plugin #{name} is already enabled")

    errors.assert (status == STATUSES.DISABLED)
    @setStatus name, STATUSES.ENABLING

    plugin = PLUGINS[name]
    api = new PluginApi @session, plugin, @
    value = plugin.enable api

    @plugin_infos[name] = {
      api: api,
      value: value
    }
    @setStatus name, STATUSES.ENABLED
    do @updateEnabledPlugins

  disable: (name) ->
    status = @getStatus name
    if status == STATUSES.UNREGISTERED
      throw new errors.GenericError("No plugin registered as #{name}")
    if status == STATUSES.ENABLING
      throw new errors.GenericError("Still enabling plugin #{name}")
    if status == STATUSES.DISABLING
      throw new errors.GenericError("Already disabling plugin #{name}")
    if status == STATUSES.DISABLED
      throw new errors.GenericError("Plugin #{name} already disabled")

    # TODO: require that no other plugin has this as a dependency, notify user otherwise
    errors.assert (status == STATUSES.ENABLED)
    @setStatus name, STATUSES.DISABLING

    plugin_info = @plugin_infos[name]
    plugin = PLUGINS[name]
    plugin.disable plugin_info.api
    delete @plugin_infos[name]
    do @updateEnabledPlugins

registerPlugin = (plugin_metadata, enable, disable) ->
  utils.tv4_validate(plugin_metadata, PLUGIN_SCHEMA, "plugin")
  utils.fill_tv4_defaults plugin_metadata, PLUGIN_SCHEMA

  errors.assert enable?, "Plugin #{plugin_metadata.name} needs to register with a callback"

  # Create the plugin object
  # Plugin stores all data about a plugin, including metadata
  # plugin.value contains the actual resolved value
  plugin = _.cloneDeep plugin_metadata
  PLUGINS[plugin.name] = plugin
  plugin.enable = enable
  plugin.disable = disable || _.once () =>
    alert "The plugin '#{plugin.name}' was disabled but doesn't support online disable functionality. Refresh to disable."

# exports
exports.PluginsManager = PluginsManager
exports.register = registerPlugin
exports.all = () -> PLUGINS
exports.get = (name) -> PLUGINS[name]
exports.names = () -> do (_.keys PLUGINS).sort
exports.STATUSES = STATUSES
