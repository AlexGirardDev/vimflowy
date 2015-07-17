class Menu
  constructor: (div, fn) ->
    @div = div
    @fn = fn

    data = new Data (new dataStore.InMemory)
    data.load {
      line: ''
      children: ['']
    }

    # a bit of a overkill-y hack, use an entire View object internally
    @view = new View data
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
    query = do @view.curLine
    if (JSON.stringify query) != (JSON.stringify @lastquery)
      @lastquery = query
      @results = @fn query
      @selection = 0

  render: () ->
    if not @div
      return

    do @div.empty

    searchBox = $('<div>').addClass('searchBox').appendTo @div
    searchBox.append $('<i>').addClass('fa fa-search').css(
      'margin-right': '10px'
    )

    searchRow = virtualDom.create virtualDom.h 'span', {}, (@view.virtualRenderLine @view.cursor.row)
    searchBox.append searchRow

    if @results.length == 0
      message = ''
      if do @view.curLineLength == 0
        message = 'Type something to search!'
        message += '<br/>'
        message += 'Ctrl+j and Ctrl+k to move up and down'
        message += '<br/>'
        message += 'Enter to select result'
        message += '<br/>'
        message += 'Esc to cancel'
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
          resultDiv.addClass 'menuSelected'
          icon = 'fa-arrow-circle-right'
        resultDiv.append $('<i>').addClass('fa ' + icon + ' bullet').css(
          'margin-right': '20px'
        )

        renderOptions = result.renderOptions || {}
        contents = renderLine result.contents, renderOptions
        resultLineDiv = virtualDom.create virtualDom.h 'span', {}, contents
        resultDiv.append resultLineDiv

  select: () ->
    if not @results.length
      return
    result = @results[@selection]
    do result.fn

if module?
  View = require('./view.coffee')
  Data = require('./data.coffee')
  dataStore = require('./datastore.coffee')

# exports
module?.exports = Menu
