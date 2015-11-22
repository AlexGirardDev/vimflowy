(() ->
  Plugins.register {
    name: "Hello World coffee example"
    version: 1
    author: "Zachary Vance"
    description: "Prints 'Hello World' when the plugin is loaded"
    dependencies: []
  }, ((api) ->
    console.log "Coffeescript example plugin: Hello, world!"
  ), (() ->
    console.log "Coffeescript example plugin: Goodbye, world!"
  )
)()
