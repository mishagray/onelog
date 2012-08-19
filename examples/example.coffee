#! /usr/local/bin/coffee

onelog = require 'onelog'

onelog.use onelog.Winston
logger = onelog.get('Foo')
logger.info 'Hello, World!'

onelog.use onelog.Logule
logger = onelog.get('Foo')
logger.info 'Hello, World!'

onelog.use onelog.Tracer
logger = onelog.get('Foo')
logger.info 'Hello, World!'

log4js = require 'log4js'
onelog.use onelog.Log4js
logger = onelog.get('Foo')
logger.info 'Hello, World!'

