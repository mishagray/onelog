# OneLog

*A simple logging consolidation library.*

*Don't be stuck with one logger, try them all without modification to your code.*

## Why?

I built this because I wanted to play around with different logging libraries without being locked into one.

Use one logging library for development and one for production.

Onelog provides a generic API to use so you can start adding logging statements and worry about which library to pick later.

## Install

    npm install onelog

NOTE: You must also install the logging library you wish to use (e.g. `npm install log4js`)
    
## Usage

Configure which logging library to use (this example uses [Log4js](https://github.com/nomiddlename/log4js-node)):

    onelog = require 'onelog'
    log4js = require 'log4js'
    onelog.use onelog.Log4js
    
Add logging statements like this:

    logger = require('onelog').get('Foo')
    logger.info 'Hello, world!'
    
    logger = require('onelog).get('Foo.Bar')
    logger.debug 'FooBar!'
    
For more examples run `npm install && coffee examples/example.coffee`

![examples](https://github.com/vjpr/onelog/tree/master/examples/examples.png)
    
## Configuration

I put all my library dependent configuration in a function so I can easily toggle between libraries.

    configureLog4js = ->
      log4js = require 'log4js'
      # configure your logging library as usual
      # e.g. log4js.setGlobalLevel 'INFO'
      onelog.use onelog.Log4js

    configureWinston = ->
      winston = require 'winston'
      onelog.use onelog.Winston
    
    #configureWinston()
    configureLog4js()

## Connect/Express

    app.use onelog.middleware,
      category: 'Middleware'
    
For Winson we use `express-winston` which provides two separate middlewares:

    app.use onelog.middleware,
      winston:
       type: 'error'
    app.use onelog.middleware,
      winston:
        type: 'request'
            
       
## Supported libraries

Out-of-the-box supported libraries:

* Winston
* Log4js-node
* Logule
* Tracer
* Caterpillar

It's easy to add support for another library. You just need to create a simple wrapper for the logging library that adheres to the `Logger` interface. Here's an example to add [Log.js](https://github.com/visionmedia/log.js/) support.

*CoffeeScript*

    class LogJS
      constructor: ->
        @Log = require 'log'
      get: (category) ->
        new @Log category
            
    onelog.use LogJS

*JavaScript*
            
    function LogJS() {
      this.Log = require("log");
    }
    Log.prototype.get = function(category) { new this.Log(category); }

    onelog.use(LogJS);

Because [Javascript lacks an equivalent for Ruby's method_missing](http://stackoverflow.com/questions/9779624/does-javascript-have-something-like-rubys-method-missing-feature) we must manually provide all custom methods we wish to call on our Logger upfront. For example, if you were using the Winston library you might have written `logger.emerg`, but when switching to Log4js this level does not exist and throws an error. Therefore you will need the following:

    onelog.use Log4js, methods: 'emerg'
    
This allows OneLog to send these events to the default logging level for the a library that doesn't support them. In the future there will be the option to map levels between libraries.

## TODO

* Tests.
* Allow passthrough of non-standard Logger methods.
* Add support for generic appender configuration.
* Add a more thorough list of allowed methods.
* Support setting global log level.
* Expose hook to allow logging to cloud logging provider.

## Thanks

[consolidate.js](https://github.com/visionmedia/consolidate.js) for inspiration.
