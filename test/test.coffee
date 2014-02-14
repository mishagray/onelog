#region Imports
chai = require 'chai'
#endregion

require('./hook_stdout').setup()

describe 'Logger', ->

describe 'Adapters', ->

  onelog = require '../src/onelog'

  describe 'log4js', ->

    log4js = require 'log4js'
    onelog.use onelog.Log4js
    logger = onelog.get 'Log4js'

    it 'should work', ->
      logger.info 'This is a test'

  describe 'Winston', ->
  describe 'Logule', ->
  describe 'Tracer', ->
