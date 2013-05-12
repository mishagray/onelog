# 3rd party libs
_ = require 'underscore'

# Hash of timers.
timers = {}

config =
  # TODO: Add a more thorough list of common methods
  methods: ['debug', 'info', 'notice', 'warning', 'error', 'crit', 'alert',
            'emerg', 'trace', 'log', 'warn', 'line', 'time', 'timeEnd',
            'profile', 'assert', 'log', 'fatal', 'dir', 'start', 'stop',
            'isLevelEnabled']

# Timers
# ------

start = (label) ->
  timers[label] = Date.now()

stop = (label) ->
  duration = Date.now() - timers[label]
  return duration

# Interfaces
# ------------------------------------------------------------------------------

# Logger wrapper delegates to underlying logger
class Logger
  constructor: (@logger) ->
    @enabled = true
    for method in config.methods
      do (method) =>
        Logger::[method] = (a...) ->
          return if not @enabled
          if method is 'start'
            start a...
          else if method is 'stop'
            stop a...
          else if @logger[method]?
            @logger[method] a...
          else
            defaultMethod = GLOBAL.onelog._library.defaultLevel()
            @logger[defaultMethod] a...
  # Disable logger for a single level or all levels if no argument
  # TODO: Level functionality
  suppress: (level) -> @enabled = false
  allow: (level) -> @enabled = true

# Logging library interface
class Library

  # Create or get a new logger
  getLogger: (category) ->
  # Get direct access to library
  get: ->
  # Get options set in library.
  getOpts: ->
  # Get an instance of the underlying library we are using if one exists.
  getLibraryInstance: ->
  # Default level when an unsupported level is encountered
  middleware: (opts) ->
    (req, res, next) -> next()
  # If library doesn't support a level, this default level is used
  defaultLevel: ->
    if @log?
      return 'log'
    else if @info?
      return 'info'
    else
      throw new Error 'Could not find a default level to fallback to'

# Default logging library
# ------------------------------------------------------------------------------

# Standard console library
class Console extends Library
  constructor: ->
  get: (category) ->
    new Logger console
  defaultLevel: -> 'log'

# The library we want to use for logging
_library = undefined

# The logger used when no namespace is defined
_defaultLogger = undefined

stackTrace = require 'stack-trace'
path = require 'path'
getCallerFile = ->
  frame = stackTrace.get()[2]
  #file = path.basename frame.getFileName()
  file = frame.getFileName()
  line = frame.getLineNumber()
  method = frame.getFunctionName()
  "#{frame.getTypeName()} #{file}: #{line} in #{method}()"

# Public API
# ------------------------------------------------------------------------------

# opts
#   - methods: Custom level. If you change to a logging library that does not
#       support these levels, a default level will be used.
exports.use = (clazz, opts = {}) ->
  # Check interface of clazz
  for k of Library::
    if not clazz?.prototype[k]
      throw new Error "
        Invalid logging library prototype.
        You must pass in a class with a prototype that adheres to Library.
        "

  # Do not allow overriding if already initialized.
  if not GLOBAL.onelog?
    GLOBAL.onelog or= {}
    GLOBAL.onelog._library = _library = new clazz opts.lib
    GLOBAL.onelog._defaultLogger = _defaultLogger = _library.get()
    console.log "OneLog is using logging library #{clazz.name} - Initialized from #{getCallerFile arguments}"
  else
    _library = GLOBAL.onelog._library
    _defaultLogger = GLOBAL.onelog._defaultLogger

  # Allow custom methods for logger specified by library.
  # E.g. log4js uses`logger.setLevel`
  if GLOBAL.onelog._library.getOpts()?
    config.methods = _.union config.methods, GLOBAL.onelog._library.getOpts().methods
  
  # Allow custom methods for logger passed in by user.
  if opts?.methods?
    config.methods = _.union config.methods, opts.methods
  for method in config.methods
    do (method) =>
      exports[method] = (a...) -> _defaultLogger[method] a...

# Create or get a logger instance
exports.get = (category) ->
  # Initiate default logger if none has been setup.
  unless GLOBAL.onelog? then exports.use Console
  GLOBAL.onelog._library.get category

# Support for logule namespaces
exports.sub = (namespaces...) ->
  GLOBAL.onelog._library.sub

exports.middleware = (opts) ->
  GLOBAL.onelog._library.middleware opts

exports.getLibrary = ->
  GLOBAL.onelog._library?.getLibrary()

# Provided library adapters
# ------------------------------------------------------------------------------

class Log4js extends Library

  name: 'Log4js'

  constructor: (@log4js) ->
    unless @log4js? then @log4js = require 'log4js'

  get: (category) ->
    if category
      return new Logger @log4js.getLogger(category)
    else
      return new Logger @log4js.getDefaultLogger()

  getOpts: ->
    return methods: 'setLevel'

  getLibrary: ->
    return @log4js

  middleware: (opts) ->
    category = opts?.category or 'Middleware'
    level = opts?.level or @log4js.levels.INFO
    # TODO: Allow more options
    return @log4js.connectLogger @log4js.getLogger(category), level: level

  defaultLevel: -> 'info'

class Logule extends Library

  name: 'Logule'

  constructor: ->
    @logule = require 'logule'

  get: (category) ->
    if category
      new Logger @logule.sub(category)
    else
      new Logger @logule

  middleware: (opts) ->
    category = opts?.category or 'Middleware'
    level = opts?.level or 'trace'
    return (req, res, next) ->
      expressLogger[level] req.method, req.url.toString()
      next()

class Winston extends Library

  name: 'Winston'

  constructor: ->
    @winston = require 'winston'

  get: (category) ->
    logger = null
    if category
      logger = new Logger @winston.loggers.add category,
        console:
          level: 'silly'
          colorize: true
    else
      logger = @winston
    logger

  middleware: (opts) ->
    @expressWinston = require 'express-winston'
    if opts?.winston.type is 'error'
      return @expressWinston.errorLogger
        transports: [
          new @winston.transports.Console
            json: true
            colorize: true
        ]
    if opts?.winston.type is 'request'
      return @expressWinston.logger
        transports: [
          new @winston.transports.Console
            json: true
            colorize: true
        ]

class Caterpillar extends Library

  name: 'Caterpillar'

  constructor: ->
    @caterpillar = require 'caterpillar'

  get: (category) ->
    new Logger (new @caterpillar.Logger)

class Tracer extends Library

  constructor: ->
    @tracer = require 'tracer'

  get: (category) ->
    new Logger @tracer.colorConsole()

exports.Logule = Logule
exports.Log4js = Log4js
exports.Winston = Winston
exports.Caterpillar = Caterpillar
exports.Tracer = Tracer
