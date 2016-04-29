Session = require './session.coffee'
Document = (require './document.coffee').Document
DataStore = require './datastore.coffee'

###
Represents the menu shown in menu mode.
Functions for paging through and selecting results, and for rendering.
Internally uses an entire session object (this is sorta weird..)
###

class Menu
  constructor: (div, fn) ->
    @div = div
    @fn = fn

    document = new Document (new DataStore.InMemory)

    # a bit of a overkill-y hack, use an entire session object internally
    @session = new Session document
    @selection = 0

    # list of results:
    #   contents: a line of contents
    #   renderOptions: options for renderLine
    #   fn: call if selected
    @results = []

  up: () ->
    if not @results.length
      return
    if @selection <= 0
      @selection = @results.length - 1
    else
      @selection = @selection - 1

  down: () ->
    if not @results.length
      return
    if @selection + 1 >= @results.length
      @selection = 0
    else
      @selection = @selection + 1

  update: () ->
    query = do @session.curText
    if (JSON.stringify query) != (JSON.stringify @lastquery)
      @lastquery = query
      @results = @fn query
      @selection = 0

  render: () ->
    if not @div
      return

    do @div.empty

    searchBox = $('<div>').addClass('searchBox theme-trim').appendTo @div
    searchBox.append $('<i>').addClass('fa fa-search').css(
      'margin-right': '10px'
    )

    searchRow = virtualDom.create virtualDom.h 'span', {}, (@session.virtualRenderLine @session.cursor.row, {cursorBetween: true, no_clicks: true})
    searchBox.append searchRow

    if @results.length == 0
      message = ''
      if do @session.curLineLength == 0
        message = 'Type something to search!'
      else
        message = 'No results!  Try typing something else'
      @div.append(
        $('<div>').html(message).css(
          'font-size': '20px'
          'opacity': '0.5'
        ).addClass('center')
      )
    else
      for result, i in @results

        resultDiv = $('<div>').css(
          'margin-bottom': '10px'
        ).appendTo @div

        icon = 'fa-circle'
        if i == @selection
          resultDiv.addClass 'theme-bg-selection'
          icon = 'fa-arrow-circle-right'
        resultDiv.append $('<i>').addClass('fa ' + icon + ' bullet').css(
          'margin-right': '20px'
        )

        renderOptions = result.renderOptions || {}
        contents = renderLine result.contents, renderOptions
        if result.renderHook?
          contents = result.renderHook contents
        resultLineDiv = virtualDom.create virtualDom.h 'span', {}, contents
        resultDiv.append resultLineDiv

  select: () ->
    if not @results.length
      return
    result = @results[@selection]
    do result.fn

# exports
module.exports = Menu
