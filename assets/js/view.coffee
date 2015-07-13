# a View consists of Data and a cursor
# it also renders
#
renderLine = (lineData, options = {}) ->
  options.cursors ?= {}
  options.highlights ?= {}
  defaultStyle = options.defaultStyle || ''

  # ideally this takes up space but is unselectable (uncopyable)
  cursorChar = ' '

  # array of dicts:
  # {
  #   text: text
  #   column: column
  #   cursor: true/false
  #   highlighted: true/false
  # }
  line = []

  # add cursor if at end
  if lineData.length of options.cursors
    lineData.push cursorChar

  # if still empty, put a newline
  if lineData.length == 0
    lineData.push '\n'

  for char, i in lineData
    info = {
      column: i
    }

    x = char

    if char == '\n'
      x = ''
      info.break = true
      if i of options.cursors
        x = cursorChar + x

    if i of options.cursors
      info.cursor = true
    if i of options.highlights
      info.highlighted = true

    info.text = x
    line.push info

  # collect set of words, { word: word, start: start, end: end }
  words = []
  word = ''
  word_start = 0

  lineData.push ' ' # to make end condition easier
  for char, i in lineData
    if char == '\n' or char == ' '
      if i != word_start
        words.push {
          word: word
          start: word_start
          end: i - 1
        }
      word_start = i + 1
      word = ''
    else
      word += char

  urlRegex = /^https?:\/\/[^\s]+\.[^\s]+$/
  url_words = words.filter (w) ->
    return urlRegex.test w.word

  for url_word in url_words
    line[url_word.start].url_start = url_word.word
    line[url_word.end].url_end = url_word.word
    # console.log 'url word', url_word

  results = []

  url = null

  for x in line
    style = defaultStyle
    if x.cursor
      style = 'cursor'
    else if x.highlighted
      style = 'highlight'

    if x.url_start
      url = x.url_start

    divtype = if url == null then 'span' else 'a'

    divoptions = {className: style}
    if url != null
      divoptions.href = url
    if options.onclick?
      divoptions.onclick = options.onclick.bind @, x

    results.push virtualDom.h divtype, divoptions, x.text

    if x.break
      results.push virtualDom.h 'div'

    if x.url_end
      url = null

  return results

class View
  containerDivID = (id) ->
    return 'node-' + id

  rowDivID = (id) ->
    return 'node-' + id + '-row'

  childrenDivID = (id) ->
    return 'node-' + id + '-children'

  constructor: (data, options = {}) ->
    @data = data
    @mainDiv = options.mainDiv
    @settingsDiv = options.settingsDiv
    @keybindingsDiv = options.keybindingsDiv

    row = (@data.getChildren @data.viewRoot)[0]
    @cursor = new Cursor @data, row, 0
    @register = new Register @

    @actions = [] # full action history
    @history = [{
      index: 0
    }]
    @historyIndex = 0 # index into indices

    if @mainDiv?
      @vtree = do @virtualRender
      @vnode = virtualDom.create @vtree
      @mainDiv.append @vnode

    if @settingsDiv?
      @settings = new Settings @data.store, {mainDiv: @settingsDiv, keybindingsDiv: @keybindingsDiv}
      do @settings.loadRenderSettings
    return @

  ##########
  # EXPORT
  ##########

  export: (filename, mimetype) ->
    filename ||= @settings?.getSetting?('export_filename') || 'vimflowy.json'
    if not mimetype? # Infer mimetype from file extension
        mimetype = @mimetypeLookup filename
    content = @exportContent mimetype
    @saveFile filename, mimetype, content

  exportContent: (mimetype) ->
    jsonContent = do @data.serialize
    if mimetype == 'application/json'
        delete jsonContent.viewRoot
        return JSON.stringify(jsonContent, undefined, 2)
    else if mimetype == 'text/plain'
        # Workflowy compatible plaintext export
        #   Ignores 'collapsed' and viewRoot
        indent = "  "
        exportLines = (node) ->
            if typeof(node) == 'string'
              return ["- #{node}"]
            lines = []
            lines.push "- #{node.line}"
            for child in node.children ? []
                for line in exportLines child
                    lines.push "#{indent}#{line}"
            return lines
        return(exportLines jsonContent).join "\n"
    else
        throw "Invalid export format"

   mimetypeLookup: (filename) ->
     parts = filename.split '.'
     extension = parts[parts.length - 1] ? ''
     extensionLookup =
       'json': 'application/json'
       'txt': 'text/plain'
       '': 'text/plain'
     return extensionLookup[extension.toLowerCase()]

  saveFile: (filename, mimetype, content) ->
    if not $?
      throw "Tried to save a file from the console, impossible"
    $("#export").attr("download", filename)
    $("#export").attr("href", "data: #{mimetype};charset=utf-8,#{encodeURIComponent(content)}")
    $("#export")[0].click()
    $("#export").attr("download", null)
    $("#export").attr("href", null)
    return content

  # ACTIONS

  save: () ->
    if @history[@historyIndex].index == @actions.length
        return
    state = @history[@historyIndex]
    state.after = {
      cursor: do @cursor.clone
      viewRoot: @data.viewRoot
    }

    @historyIndex += 1
    @history.push {
      index: @actions.length
    }

  restoreViewState: (state) ->
    @cursor =  do state.cursor.clone
    @changeView state.viewRoot

  undo: () ->
    if @historyIndex > 0
      oldState = @history[@historyIndex]
      @historyIndex -= 1
      newState = @history[@historyIndex]

      for i in [(oldState.index-1)...(newState.index-1)]
          action = @actions[i]
          action.rewind @

      @restoreViewState newState.before

  redo: () ->
    if @historyIndex < @history.length - 1
      oldState = @history[@historyIndex]
      @historyIndex += 1
      newState = @history[@historyIndex]

      for i in [oldState.index...newState.index]
          action = @actions[i]
          action.reapply @
      @restoreViewState oldState.after

  act: (action) ->
    if @historyIndex + 1 != @history.length
        @history = @history.slice 0, (@historyIndex + 1)
        @actions = @actions.slice 0, @history[@historyIndex].index

    state = @history[@historyIndex]
    if @actions.length == state.index
      state.before = {
        cursor: do @cursor.clone
        viewRoot: @data.viewRoot
      }

    action.apply @
    @actions.push action

  # CURSOR MOVEMENT AND DATA MANIPULATION

  curLine: () ->
    return @data.getLine @cursor.row

  curLineLength: () ->
    return @data.getLength @cursor.row

  changeView: (row) ->
    if @data.hasChildren row
      @data.changeViewRoot row
      return true
    return false

  rootInto: (row = @cursor.row) ->
    # try changing to cursor
    if @reroot row
      return true
    parent = @data.getParent row
    if @reroot parent
      @cursor.setRow row
      return true
    throw 'Failed to root into'

  rootUp: () ->
    if @data.viewRoot != @data.root
      parent = @data.getParent @data.viewRoot
      @reroot parent

  rootDown: () ->
    newroot = @data.oldestVisibleAncestor @cursor.row
    if @reroot newroot
      return true
    return false

  reroot: (newroot = @data.root) ->
    if @changeView newroot
      newrow = @data.youngestVisibleAncestor @cursor.row
      if newrow == null # not visible, need to reset cursor
        newrow = (@data.getChildren newroot)[0]
      @cursor.setRow newrow
      return true
    return false

  addCharsAtCursor: (chars, options) ->
    @act new actions.AddChars @cursor.row, @cursor.col, chars, options

  addCharsAfterCursor: (chars, options) ->
    col = @cursor.col
    if col < (@data.getLength @cursor.row)
      col += 1
    @act new actions.AddChars @cursor.row, col, chars, options

  delChars: (row, col, nchars, options = {}) ->
    n = @data.getLength row
    if (n > 0) and (nchars > 0) and (col < n)
      delAction = new actions.DelChars row, col, nchars, options
      @act delAction
      if options.yank
        @register.saveChars delAction.deletedChars

  delCharsBeforeCursor: (nchars, options) ->
    nchars = Math.min(@cursor.col, nchars)
    @delChars @cursor.row, (@cursor.col-nchars), nchars, options

  delCharsAfterCursor: (nchars, options) ->
    @delChars @cursor.row, @cursor.col, nchars, options

  spliceCharsAfterCursor: (nchars, chars, options) ->
    @delCharsAfterCursor nchars, {cursor: {pastEnd: true}}
    @addCharsAtCursor chars, options

  yankChars: (row, col, nchars) ->
    line = @data.getLine row
    if line.length > 0
      @register.saveChars line.slice(col, col + nchars)

  # options:
  #   - includeEnd says whether to also delete cursor2 location
  yankBetween: (cursor1, cursor2, options = {}) ->
    if cursor2.row != cursor1.row
      console.log('not yet implemented')
      return

    if cursor2.col < cursor1.col
      [cursor1, cursor2] = [cursor2, cursor1]

    offset = if options.includeEnd then 1 else 0
    @yankChars cursor1.row, cursor1.col, (cursor2.col - cursor1.col + offset)

  # options:
  #   - includeEnd says whether to also delete cursor2 location
  deleteBetween: (cursor1, cursor2, options = {}) ->
    if cursor2.row != cursor1.row
      console.log('not yet implemented')
      return

    if cursor2.col < cursor1.col
      [cursor1, cursor2] = [cursor2, cursor1]
    offset = if options.includeEnd then 1 else 0
    @delChars cursor1.row, cursor1.col, (cursor2.col - cursor1.col + offset), options

  newLineBelow: () ->
    children = @data.getChildren @cursor.row
    if (not @data.collapsed @cursor.row) and children.length > 0
      @act new actions.InsertRowSibling children[0], {before: true}
    else
      @act new actions.InsertRowSibling @cursor.row, {after: true}

  newLineAbove: () ->
    @act new actions.InsertRowSibling @cursor.row, {before: true}

  newLineAtCursor: () ->
    delAction = new actions.DelChars @cursor.row, 0, @cursor.col
    @act delAction
    row = @cursor.row
    sibling = @act new actions.InsertRowSibling @cursor.row, {before: true}
    @addCharsAfterCursor delAction.deletedChars
    @cursor.set row, 0

  joinRows: (first, second, options = {}) ->
    for child in @data.getChildren second by -1
      # NOTE: if first is collapsed, should we uncollapse?
      @moveBlock child, first, 0

    line = @data.getLine second
    if options.delimiter
      if line[0] != options.delimiter
        line = [options.delimiter].concat line
    @detachBlock second

    newCol = @data.getLength first
    action = new actions.AddChars first, newCol, line
    @act action

    @cursor.set first, newCol, options.cursor

  joinAtCursor: () ->
    row = @cursor.row
    sib = @data.nextVisible row
    if sib != null
      @joinRows row, sib, {cursor: {pastEnd: true}, delimiter: ' '}

  # implements proper "backspace" behavior
  deleteAtCursor: () ->
    if @cursor.col == 0
      row = @cursor.row
      sib = @data.prevVisible row
      if sib != null
        @joinRows sib, row, {cursor: {pastEnd: true}}
    else
      @delCharsBeforeCursor 1, {cursor: {pastEnd: true}}

  delBlocks: (nrows, options = {}) ->
    action = new actions.DeleteBlocks @cursor.row, nrows, options
    @act action
    @register.saveRows action.serialized_rows

  addBlocks: (serialized_rows, parent, index = -1, options = {}) ->
    action = new actions.AddBlocks serialized_rows, parent, index, options
    @act action

  yankBlocks: (nrows) ->
    siblings = @data.getSiblingRange @cursor.row, 0, (nrows-1)
    siblings = siblings.filter ((x) -> return x != null)
    serialized = siblings.map ((x) => return @data.serialize x)
    @register.saveRows serialized

  detachBlock: (row, options = {}) ->
    action = new actions.DetachBlock row, options
    @act action
    return action

  attachBlock: (row, parent, index = -1, options = {}) ->
    @act new actions.AttachBlock row, parent, index, options

  moveBlock: (row, parent, index = -1, options = {}) ->
    @detachBlock row, options
    @attachBlock row, parent, index, options

  indentBlocks: (id, numblocks = 1) ->
    newparent = @data.getSiblingBefore id
    if newparent == null
      return null # cannot indent

    if @data.collapsed newparent
      @toggleBlock newparent

    siblings = @data.getSiblingRange id, 0, (numblocks-1)
    for sib in siblings
      @moveBlock sib, newparent, -1
    return newparent

  unindentBlocks: (id, numblocks = 1, options = {}) ->
    parent = @data.getParent id
    if parent == @data.viewRoot
      return null

    siblings = @data.getSiblingRange id, 0, (numblocks-1)

    newparent = @data.getParent parent
    pp_i = @data.indexOf parent

    for sib in siblings
      pp_i += 1
      @moveBlock sib, newparent, pp_i
    return newparent

  indent: (id = @cursor.row) ->
    sib = @data.getSiblingBefore id

    newparent = @indentBlocks id
    if newparent == null
      return
    for child in (@data.getChildren id).slice()
      @moveBlock child, sib, -1

  unindent: (id = @cursor.row) ->
    if @data.hasChildren id
      return

    parent = @data.getParent id
    p_i = @data.indexOf id

    newparent = @unindentBlocks id
    if newparent == null
      return

    p_children = @data.getChildren parent
    for child in p_children.slice(p_i)
      @moveBlock child, id, -1

  swapDown: (row = @cursor.row) ->
    next = @data.nextVisible (@data.lastVisible row)
    if next == null
      return

    @detachBlock row
    if (@data.hasChildren next) and (not @data.collapsed next)
      # make it the first child
      @attachBlock row, next, 0
    else
      # make it the next sibling
      parent = @data.getParent next
      p_i = @data.indexOf next
      @attachBlock row, parent, (p_i+1)

  swapUp: (row = @cursor.row) ->
    prev = @data.prevVisible row
    if prev == null
      return

    @detachBlock row
    # make it the previous sibling
    parent = @data.getParent prev
    p_i = @data.indexOf prev
    @attachBlock row, parent, p_i

  toggleCurBlock: () ->
    @toggleBlock @cursor.row

  toggleBlock: (row) ->
    @act new actions.ToggleBlock row

  pasteBefore: (options = {}) ->
    options.before = true
    @register.paste options

  pasteAfter: (options = {}) ->
    @register.paste options

  find: (chars, nresults = 10) ->
    results = @data.find chars, nresults
    return results

  scrollPages: (npages) ->
    # TODO:  find out height per line, figure out number of lines to move down, scroll down corresponding height
    line_height = do $('.node-text').height
    page_height = do $(document).height
    height = npages * page_height

    numlines = Math.round(height / line_height)
    if numlines > 0
      for i in [1..numlines]
        do @cursor.down
    else
      for i in [-1..numlines]
        do @cursor.up

    @scrollMain (line_height * numlines)

  scrollMain: (amount) ->
     # # animate.  seems to not actually be great though
     # @mainDiv.stop().animate({
     #     scrollTop: @mainDiv[0].scrollTop + amount
     #  }, 50)
     @mainDiv.scrollTop(@mainDiv.scrollTop() + amount)

  scrollIntoView: (el) ->
    elemTop = el.getBoundingClientRect().top
    elemBottom = el.getBoundingClientRect().bottom

    margin = 50
    top_margin = margin
    bottom_margin = margin + $('#bottom-bar').height()

    if elemTop < top_margin
       # scroll up
       @scrollMain (elemTop - top_margin)
    else if elemBottom > window.innerHeight - bottom_margin
       # scroll down
       @scrollMain (elemBottom - window.innerHeight + bottom_margin)

  # RENDERING

  virtualRender: () ->
    crumbs = []
    row = @data.viewRoot
    while row != @data.root
      crumbs.push row
      row = @data.getParent row

    makeCrumb = (row, line) =>
      return virtualDom.h 'span', {
        className: 'crumb'
      }, [
        virtualDom.h 'a', {
          onclick: () =>
            @reroot row
            do @save
            do @render
        }, [ line ]
      ]

    crumbNodes = []
    crumbNodes.push(makeCrumb @data.root, (virtualDom.h 'icon', {className: 'fa fa-home'}))
    for row in crumbs by -1
      line = (@data.getLine row).join('')
      crumbNodes.push(makeCrumb row, line)

    breadcrumbsNode = virtualDom.h 'div', {
      id: 'breadcrumbs'
    }, crumbNodes

    contentsChildren = @virtualRenderTree @data.viewRoot, {ignoreCollapse: true}

    contentsNode = virtualDom.h 'div', {
      id: 'treecontents'
      className: 'unselectable'
    }, contentsChildren

    return virtualDom.h 'div', {
    }, [breadcrumbsNode, contentsNode]

  render: () ->
    vtree = do @virtualRender
    patches = virtualDom.diff @vtree, vtree
    @vnode = virtualDom.patch @vnode, patches
    @vtree = vtree

    cursorDiv = $('.cursor', @mainDiv)[0]
    if cursorDiv
      @scrollIntoView cursorDiv
    return

  virtualRenderTree: (parentid, options = {}) ->
    if (not options.ignoreCollapse) and (@data.collapsed parentid)
      return

    childrenNodes = []

    highlighted = {}
    if @lineSelect
      if parentid == @data.getParent @cursor.row
        index1 = @data.indexOf @cursor.row
        index2 = @data.indexOf @anchor.row
        if index2 < index1
          [index1, index2] = [index2, index1]
        for i in [index1..index2]
          highlighted[i] = true

    for i, id of @data.getChildren parentid

      icon = 'fa-circle'
      if @data.hasChildren id
        icon = if @data.collapsed id then 'fa-plus-circle' else 'fa-minus-circle'

      bulletOpts = {
        className: 'fa ' + icon + ' bullet'
      }
      if @data.hasChildren id
        bulletOpts.style = {cursor: 'pointer'}
        bulletOpts.onclick = ((id) =>
          @toggleBlock id
          do @render
        ).bind(@, id)

      bullet = virtualDom.h 'i', bulletOpts

      elLine = virtualDom.h 'div', {
        id: rowDivID id
        className: 'node-text'
      }, @virtualRenderLine id

      children = virtualDom.h 'div', {
        id: childrenDivID id
        className: 'node-children'
      }, (@virtualRenderTree id)

      className = 'node'
      if i of highlighted
        className += ' highlight'

      childNode = virtualDom.h 'div', {
        id: containerDivID id
        className: className
      }, [bullet, elLine, children]

      childrenNodes.push childNode
    return childrenNodes

  virtualRenderLine: (row) ->

    lineData = @data.getLine row
    cursors = {}
    highlights = {}

    if row == @cursor.row
      cursors[@cursor.col] = true

      if @anchor and not @lineSelect
        if row == @anchor.row
          for i in [@cursor.col..@anchor.col]
            highlights[i] = true
        else
          console.log('multiline not implemented')

    lineContents = renderLine lineData, {
      cursors: cursors
      highlights: highlights
      onclick: (x) =>
        @cursor.set row, x.column
        do @render
    }

    return lineContents

# imports
if module?
  Cursor = require('./cursor.coffee')
  actions = require('./actions.coffee')
  Register = require('./register.coffee')

# exports
module?.exports = View
