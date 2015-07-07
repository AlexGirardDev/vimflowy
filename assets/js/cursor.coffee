class Cursor
  constructor: (data, row = null, col = null, moveCol = null) ->
    @data = data
    @row = if row == null then (@data.getChildren @data.viewRoot)[0] else row
    @col = if col == null then 0 else col

    # -1 means last col
    @moveCol = if moveCol == null then col else moveCol

  clone: () ->
    return new Cursor @data, @row, @col, @moveCol

  # cursorOptions:
  #   - pastEnd:      means whether we're on the column or past it.
  #                   generally true when in insert mode but not in normal mode
  #                   effectively decides whether we can go past last column or not
  #   - pastEndWord:  whether we consider the end of a word to be after the last letter
  #                   is true in normal mode (for de), false in visual (for vex)

  set: (row, col, cursorOptions) ->
    @row = row
    @setCol col, cursorOptions

  setRow: (row, cursorOptions) ->
    @row = row
    @fromMoveCol cursorOptions

  setCol: (moveCol, cursorOptions = {pastEnd: true}) ->
    @moveCol = moveCol
    @fromMoveCol cursorOptions
    # if cursorOptions moved us, we should respect it
    # this is the time to do so, since we're setting moveCol
    if @moveCol >= 0
      @moveCol = @col

  fromMoveCol: (cursorOptions = {}) ->
    len = @data.getLength @row
    maxcol = len - (if cursorOptions.pastEnd then 0 else 1)
    if @moveCol < 0
      @col = Math.max(0, len + @moveCol + 1)
    else
      @col = Math.max(0, Math.min(maxcol, @moveCol))

  _left: () ->
    @setCol (@col - 1)

  _right: () ->
    @setCol (@col + 1)

  left: () ->
    if @col > 0
      do @_left

  right: (cursorOptions = {}) ->
    shift = if cursorOptions.pastEnd then 0 else 1
    if @col < (@data.getLength @row) - shift
      do @_right

  backIfNeeded: () ->
    if @col > (@data.getLength @row) - 1
      do @left

  atVisibleEnd: () ->
    if @col < (@data.getLength @row) - 1
      return false
    else
      nextrow = @data.nextVisible @row
      if nextrow != null
        return false
    return true

  nextChar: () ->
    if @col < (@data.getLength @row) - 1
      do @_right
      return true
    else
      nextrow = @data.nextVisible @row
      if nextrow != null
        @set nextrow, 0
        return true
    return false

  atVisibleStart: () ->
    if @col > 0
      return false
    else
      prevrow = @data.prevVisible @row
      if prevrow != null
        return false
    return true

  prevChar: () ->
    if @col > 0
      do @_left
      return true
    else
      prevrow = @data.prevVisible @row
      if prevrow != null
        @set prevrow, -1
        return true
    return false

  home: () ->
    @setCol 0
    return @

  end: (cursorOptions = {cursor: {}}) ->
    @setCol (if cursorOptions.pastEnd then -1 else -2)
    return @

  visibleHome: () ->
    row = do @data.nextVisible
    @set row, 0

  visibleEnd: () ->
    row = do @data.lastVisible
    @set row, 0

  wordRegex = /^[a-z0-9_]+$/i

  isWhitespace = (char) ->
    return (char == ' ') or (char == undefined)

  isInWhitespace: (row, col) ->
    char = @data.getChar row, col
    return isWhitespace char

  isInWord: (row, col, matchChar) ->
    if isWhitespace matchChar
      return false

    char = @data.getChar row, col
    if isWhitespace char
      return false

    if wordRegex.test char
      return wordRegex.test matchChar
    else
      return not wordRegex.test matchChar

  getWordCheck: (options, matchChar) ->
    if options.whitespaceWord
      return ((row, col) => not @isInWhitespace row, col)
    else
      return ((row, col) => @isInWord row, col, matchChar)

  beginningWord: (options = {}) ->
    if do @atVisibleStart
      return
    do @prevChar
    while (not do @atVisibleStart) and @isInWhitespace @row, @col
      do @prevChar

    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while (@col > 0) and wordcheck @row, (@col-1)
      do @_left

  endWord: (options = {}) ->
    if do @atVisibleEnd
      if options.cursor.pastEnd
        do @_right
      return

    do @nextChar
    while (not do @atVisibleEnd) and @isInWhitespace @row, @col
      do @nextChar

    end = (@data.getLength @row) - 1
    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      do @_right

    if options.cursor.pastEndWord
      do @_right

    end = (@data.getLength @row) - 1
    if @col == end and options.cursor.pastEnd
      do @_right

  nextWord: (options = {}) ->
    if do @atVisibleEnd
      if options.cursor.pastEnd
        do @_right
      return

    end = (@data.getLength @row) - 1
    wordcheck = @getWordCheck options, (@data.getChar @row, @col)
    while @col < end and wordcheck @row, (@col+1)
      do @_right

    do @nextChar
    while (not do @atVisibleEnd) and @isInWhitespace @row, @col
      do @nextChar

    end = (@data.getLength @row) - 1
    if @col == end and options.cursor.pastEnd
      do @_right

  findNextChar: (char, options = {}) ->
    end = (@data.getLength @row) - 1
    if @col == end
      return

    col = @col
    if options.beforeFound
      col += 1

    found = null
    while col < end
      col += 1
      if (@data.getChar @row, col) == char
        found = col
        break

    if found == null
      return

    @setCol found
    if options.cursor.pastEnd
      do @_right
    if options.beforeFound
      do @_left

  findPrevChar: (char, options = {}) ->
    if @col == 0
      return

    col = @col
    if options.beforeFound
      col -= 1

    found = null
    while col > 0
      col -= 1
      if (@data.getChar @row, col) == char
        found = col
        break

    if found == null
      return

    @setCol found
    if options.beforeFound
      do @_right

  up: (cursorOptions = {}) ->
    row = @data.prevVisible @row
    if row != null
      @setRow row, cursorOptions

  down: (cursorOptions = {}) ->
    row = @data.nextVisible @row
    if row != null
      @setRow row, cursorOptions

  parent: (cursorOptions = {}) ->
    row = @data.getParent @row
    if row == @data.root
      return
    if row == @data.viewRoot
      @data.changeViewRoot @data.getParent row
    @setRow row, cursorOptions

  prevSibling: (cursorOptions = {}) ->
    prevsib = @data.getSiblingBefore @row
    if prevsib != null
      @setRow prevsib, cursorOptions

  nextSibling: (cursorOptions = {}) ->
    nextsib = @data.getSiblingAfter @row
    if nextsib != null
      @setRow nextsib, cursorOptions

# exports
module?.exports = Cursor
