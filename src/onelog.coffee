# 3rd party libs
_ = require 'underscore'

# Hash of timers.
timers = {}

config =
  # TODO: Add a more thorough list of common methods
  methods: ['debug', 'info', 'notice', 'warning', 'error', 'crit', 'alert',
            'emerg', 'trace', 'log', 'warn', 'line', 'time', 'timeEnd',
            'profile', 'assert', 'log', 'fatal', 'dir', 'start', 'stop']

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
            @logger[method] = time
          else if method is 'stop'
            @logger[method] = timeEnd
          else if @logger[method]?
            @logger[method] a...
          else
            defaultMethod = _library.defaultLevel()
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

# The library we want to use for logging
_library = undefined

# The logger used when no namespace is defined
_defaultLogger = undefined

# Public API
# ------------------------------------------------------------------------------

# opts
#   - methods: Custom level. If you change to a logging library that does not
#       support these levels, a default level will be used.
exports.use = (clazz, opts) ->
  # Check interface of clazz
  for k of Library::
    if not clazz?.prototype[k]
      throw new Error "
        Invalid logging library prototype.
        You must pass in a class with a prototype that adheres to Library.
        "
  _library = new clazz
  _defaultLogger = _library.get()
  if opts?.methods?
    config.methods = _.union config.methods, opts.methods
  for method in config.methods
    do (method) =>
      exports[method] = (a...) -> _defaultLogger[method] a...

# Create or get a logger instance
exports.get = (category) ->
  _library.get category

# Support for logule namespaces
exports.sub = (namespaces...) ->
  _library.sub

exports.middleware = (opts) ->
  _library.middleware opts

# Provided library adapters
# ------------------------------------------------------------------------------

class Log4js extends Library

  constructor: ->
    @log4js = require 'log4js'

  get: (category) ->
    if category
      return new Logger @log4js.getLogger(category)
    else
      return new Logger @log4js.getDefaultLogger()

  middleware: (opts) ->
    category = opts?.category or 'Middleware'
    level = opts?.level or @log4js.levels.INFO
    # TODO: Allow more options
    return @log4js.connectLogger @log4js.getLogger(category), level: level

  defaultLevel: -> 'info'

class Logule extends Library

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

# Initiate default logger
exports.use Console
