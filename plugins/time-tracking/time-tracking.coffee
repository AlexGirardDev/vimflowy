# Time-tracking keeps track of the amount of time spent in each subtree.
# Clones are double-counted. This is a known bug and will not be fixed.
(() ->

  Plugins.register {
    name: "Time Tracking"
    author: "Zachary Vance"
    description: "Keeps track of how much time has been spent in each row (including its descendants)"
    version: 3
  }, (api) ->
    time_tracker = new TimeTrackingPlugin api

  class TimeTrackingPlugin
    constructor: (@api) ->
      do @enableAPI

    enableAPI: () ->
      @logger = @api.logger
      @logger.info "Loading time tracking"
      @api.cursor.on 'rowChange', (@onRowChange.bind @)
      @onRowChange null, @api.cursor.row # Initial setup
      @api.view.addHook 'renderInfoElements', (@renderTime.bind @)
      @api.view.data.on 'afterDescendantRemoved', (@onDescendantRemoved.bind @)
      @api.view.data.on 'afterDescendantAdded', (@onDescendantAdded.bind @)
      @api.view.data.on 'beforeRowRemoved', (@onRowRemoved.bind @)
      @api.view.data.on 'afterRowAdded', (@onRowAdded.bind @)
      @rowChanges = []
      @currentRow = null
      @api.view.on 'exit', () =>
        @onRowChange @currentRow, null
      CMD_TOGGLE = @api.registerCommand {
        name: 'TOGGLE'
        default_hotkeys:
          normal_like: ['Z']
      }
      CMD_TOGGLE_DISPLAY = @api.registerCommand {
        name: 'TOGGLE_DISPLAY'
        default_hotkeys:
          normal_like: ['d']
      }
      CMD_TOGGLE_LOGGING = @api.registerCommand {
        name: 'TOGGLE_LOGGING'
        default_hotkeys:
          normal_like: ['l']
      }
      @api.registerAction [@api.modes.NORMAL], CMD_TOGGLE, {
        description: 'Toggle a setting',
      }, {}
      @api.registerAction [@api.modes.NORMAL], [CMD_TOGGLE, CMD_TOGGLE_DISPLAY], {
        description: 'Toggle whether time spent on each row is displayed',
      }, () =>
        do @toggleDisplay
      @api.registerAction [@api.modes.NORMAL], [CMD_TOGGLE, CMD_TOGGLE_LOGGING], {
        description: 'Toggle whether time is being logged',
      }, () =>
        do @toggleLogging


    getRowData: (id, keytype) ->
      key = "#{id}:#{keytype}"
      @api.getData key

    setRowData: (id, keytype, value) ->
      key = "#{id}:#{keytype}"
      @api.setData key, value

    transformRowData: (id, keytype, transform) ->
      @setRowData id, keytype, (transform (@getRowData id, keytype))

    isLogging: () ->
      @api.getData "isLogging", true

    toggleLogging: () ->
      isLogging = do @isLogging
      @logger.info "Turning logging #{if isLogging then "off" else "on"}"
      if isLogging
        @onRowChange @api.cursor.row, null # Final close
      else
        @onRowChange null, @api.cursor.row # Initial setup
      @api.setData "isLogging", (not isLogging)
      do @api.view.render

    shouldDisplayTime: () ->
      @api.getData "display", true

    toggleDisplay: () ->
      shouldDisplay = do @shouldDisplayTime
      @logger.info "Turning display #{if shouldDisplay then "off" else "on"}"
      @api.setData "display", (not shouldDisplay)
      do @api.view.render

    onRowChange: (from, to) ->
      @logger.debug "Switching from row #{from?.id} to row #{to?.id}"
      if not do @isLogging
        return
      time = new Date()
      if @currentRow and @currentRow.id != to?.id
        @onRowPeriod { start: @currentRow.time, stop: time, id: @currentRow.id, row: from }
        delete @currentRow
      if to?
        @currentRow ?= { id: to.id, time: time }

    onRowPeriod: (period) ->
      period.time ?= period.stop - period.start
      @_addTimeToRow period.row, period.time, period.stop
      @_addTimeToAncestors period.row, period.time, period.stop

    onDescendantRemoved: (event) ->
      @logger.debug "Descendant #{event.descendantId} removed from #{event.ancestorId}"
      # Could avoid lookups by knowing exact changes, if needed
      @_rebuildTreeTimes event.ancestorId

    onDescendantAdded: (event) ->
      @logger.debug "Descendant #{event.descendantId} added to #{event.ancestorId}"
      # Could avoid lookups by knowing exact changes, if needed
      @_rebuildTreeTimes event.ancestorId

    _addTimeToRow: (row, time, day) ->
      @transformRowData row.id, "rowTotalTime", (current) ->
        (current ? 0) + time

    _addTimeToAncestors: (row, time, day) ->
      for ancestorId in @api.view.data.allAncestors row.id, { inclusive: true }
        @transformRowData ancestorId, "treeTotalTime", (current) ->
          (current ? 0) + time

    _rebuildTreeTimes: (id) ->
      children = @api.view.data._getChildren id
      deletedChildren = (@getRowData id, 'deletedChildren') ? {}

      childTotalTimes = _.map children, (child_id) => @getRowData child_id, "treeTotalTime"
      rowTotalTime = @getRowData id, "rowTotalTime"
      deletedChildrenTotalTimes = _.map deletedChildren, (x) -> x['totalTime']
      totalTimes = _.compact [rowTotalTime].concat(childTotalTimes).concat(deletedChildrenTotalTimes)
      totalTime = totalTimes.reduce (a,b) -> (a+b)
      @setRowData id, "treeTotalTime", totalTime

    onRowRemoved: (event) ->
      deletedChildren = (@getRowData event.parent_id, 'deletedChildren') ? {}
      deletedChildren[event.id] = {
        totalTime: (@getRowData event.id, "treeTotalTime") ? 0
      }
      @setRowData event.parent_id, 'deletedChildren', deletedChildren
      for ancestor_id in @api.view.data.allAncestors event.id, { inclusive: false }
        @_rebuildTreeTimes ancestor_id

    onRowAdded: (event) ->
      deletedChildren = (@getRowData event.parent_id, 'deletedChildren') ? {}
      if event.id of deletedChildren
        delete deletedChildren[event.id]
        @setRowData event.parent_id, 'deletedChildren', deletedChildren
        for ancestor_id in @api.view.data.allAncestors event.id, { inclusive: false }
          @_rebuildTreeTimes ancestor_id

    rowTime: (row) ->
      @getRowData row.id, "treeTotalTime"

    pad = (val, length, padChar = '0') ->
      val += ''
      numPads = length - val.length
      if (numPads > 0) then new Array(numPads + 1).join(padChar) + val else val

    printTime: (ms) ->
      seconds = Math.floor (ms /     1000 % 60)
      minutes = Math.floor (ms /    60000 % 60)
      hours   = Math.floor (ms /  3600000 % 60)
      days    = Math.floor (ms / 86400000)
      if days > 0
        "#{days}d"
      else if hours > 0
        "#{hours}:#{pad(minutes, 2)}h"
      else if minutes > 0
        "#{minutes}:#{pad(seconds, 2)}m"
      else if seconds > 0
        "#{seconds}s"

    renderTime: (elements, renderData) ->
      if do @shouldDisplayTime
        time = @rowTime renderData.row
        if time > 1000
          @logger.debug "Rendering time for row #{renderData.row.id} as #{time}"
          elements.push virtualDom.h 'span', {
            className: 'time'
          }, " " + (@printTime time)
      elements
)()
