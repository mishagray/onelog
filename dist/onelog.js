'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});

var _underscore = require('underscore');

var _underscore2 = _interopRequireDefault(_underscore);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

// Hash of timers.
const timers = {}; // 3rd party libs


const config = {
  // TODO: Add a more thorough list of common methods
  methods: ['debug', 'info', 'notice', 'warning', 'error', 'crit', 'alert', 'emerg', 'trace', 'log', 'warn', 'line', 'time', 'timeEnd', 'profile', 'assert', 'log', 'fatal', 'dir', 'start', 'stop', 'isLevelEnabled']
};

// Timers
// ------

const start = label => timers[label] = Date.now();

const stop = function (label) {
  const duration = Date.now() - timers[label];
  return duration;
};

// Interfaces
// ------------------------------------------------------------------------------

// Logger wrapper delegates to underlying logger
class Logger {
  constructor(logger) {
    this.logger = logger;
    this.enabled = true;
    for (let method of Array.from(config.methods)) {
      (method => {
        return Logger.prototype[method] = function (...a) {
          if (!this.enabled) {
            return;
          }
          if (method === 'start') {
            return start(...Array.from(a || []));
          } else if (method === 'stop') {
            return stop(...Array.from(a || []));
          } else if (method === 'time') {
            return start(...Array.from(a || []));
          } else if (method === 'timeEnd') {
            return this.logger.debug(`${a}: ${stop(...Array.from(a || []))}ms`);
          } else if (this.logger[method]) {
            return this.logger[method](...Array.from(a || []));
          } else {
            const defaultMethod = GLOBAL.onelog._library.defaultLevel();
            return this.logger[defaultMethod](...Array.from(a || []));
          }
        };
      })(method);
    }
  }
  // Disable logger for a single level or all levels if no argument
  // TODO: Level functionality
  suppress(level) {
    return this.enabled = false;
  }
  allow(level) {
    return this.enabled = true;
  }
}

// Logging library interface
class Library {

  // Create or get a new logger
  getLogger(category) {}
  // Get direct access to library
  get() {}
  // Get options set in library.
  getOpts() {}
  // Get an instance of the underlying library we are using if one exists.
  getLibraryInstance() {}
  // Default level when an unsupported level is encountered
  middleware(opts) {
    return (req, res, next) => next();
  }
  // If library doesn't support a level, this default level is used
  defaultLevel() {
    if (this.log) {
      return 'log';
    } else if (this.info) {
      return 'info';
    } else {
      throw new Error('Could not find a default level to fallback to');
    }
  }
}

// Default logging library
// ------------------------------------------------------------------------------

// Standard console library
class Console extends Library {
  constructor() {
    super();
  }
  get(category) {
    return new Logger(console);
  }
  defaultLevel() {
    return 'log';
  }
}

// The library we want to use for logging
let _library = undefined;

// The logger used when no namespace is defined
let _defaultLogger = undefined;

const stackTrace = require('stack-trace');
const path = require('path');
const getCallerFile = function () {
  const frame = stackTrace.get()[2];
  //file = path.basename frame.getFileName()
  const file = frame.getFileName();
  const line = frame.getLineNumber();
  const method = frame.getFunctionName();
  return `${frame.getTypeName()} ${file}: ${line} in ${method}()`;
};

// Public API
// ------------------------------------------------------------------------------

// opts
//   - methods: Custom level. If you change to a logging library that does not
//       support these levels, a default level will be used.
let defaultExport = {};
defaultExport.use = function (clazz, opts) {
  // Check interface of clazz
  if (!opts) {
    opts = {};
  }
  for (let k in Library.prototype) {
    if (!(clazz ? clazz.prototype[k] : undefined)) {
      throw new Error(`\
Invalid logging library prototype. \
You must pass in a class with a prototype that adheres to Library.\
`);
    }
  }

  // Do not allow overriding if already initialized.
  if (!GLOBAL.onelog) {
    if (!GLOBAL.onelog) {
      GLOBAL.onelog = {};
    }
    GLOBAL.onelog._library = _library = new clazz(opts.lib);
    GLOBAL.onelog._defaultLogger = _defaultLogger = _library.get();
    console.log(`OneLog is using logging library ${clazz.name} - Initialized from ${getCallerFile(arguments)}`);
  } else {
    ({ _library } = GLOBAL.onelog);
    ({ _defaultLogger } = GLOBAL.onelog);
  }

  // Allow custom methods for logger specified by library.
  // E.g. log4js uses`logger.setLevel`
  if (GLOBAL.onelog._library.getOpts()) {
    config.methods = _underscore2.default.union(config.methods, GLOBAL.onelog._library.getOpts().methods);
  }

  // Allow custom methods for logger passed in by user.
  if (opts ? opts.methods : undefined) {
    config.methods = _underscore2.default.union(config.methods, opts.methods);
  }
  return Array.from(config.methods).map(method => (method => {
    return defaultExport[method] = (...a) => _defaultLogger[method](...Array.from(a || []));
  })(method));
};

// Create or get a logger instance
defaultExport.get = function (category) {
  // Initiate default logger if none has been setup.
  if (!GLOBAL.onelog) {
    defaultExport.use(Console);
  }
  return GLOBAL.onelog._library.get(category);
};

// Support for logule namespaces
defaultExport.sub = (...namespaces) => GLOBAL.onelog._library.sub;

defaultExport.middleware = opts => GLOBAL.onelog._library.middleware(opts);

defaultExport.getLibrary = () => GLOBAL.onelog._library ? GLOBAL.onelog._library.getLibrary() : undefined;

// Provided library adapters
// ------------------------------------------------------------------------------

class Log4js extends Library {
  static initClass() {

    this.prototype.name = 'Log4js';
  }

  constructor(log4js) {
    super();
    this.log4js = log4js;
    if (!this.log4js) {
      this.log4js = require('log4js');
    }
  }

  get(category) {
    if (category) {
      return new Logger(this.log4js.getLogger(category));
    } else {
      return new Logger(this.log4js.getDefaultLogger());
    }
  }

  getOpts() {
    return { methods: 'setLevel' };
  }

  getLibrary() {
    return this.log4js;
  }

  middleware(opts) {
    const category = (opts ? opts.category : undefined) || 'Middleware';
    const level = (opts ? opts.level : undefined) || this.log4js.levels.INFO;
    // TODO: Allow more options
    return this.log4js.connectLogger(this.log4js.getLogger(category), { level });
  }

  defaultLevel() {
    return 'info';
  }
}
Log4js.initClass();

class Logule extends Library {
  static initClass() {

    this.prototype.name = 'Logule';
  }

  constructor() {
    super();
    this.logule = require('logule');
  }

  get(category) {
    if (category) {
      return new Logger(this.logule.sub(category));
    } else {
      return new Logger(this.logule);
    }
  }

  middleware(opts) {
    const category = (opts ? opts.category : undefined) || 'Middleware';
    const level = (opts ? opts.level : undefined) || 'trace';
    return function (req, res, next) {
      expressLogger[level](req.method, req.url.toString());
      return next();
    };
  }
}
Logule.initClass();

class Winston extends Library {
  static initClass() {

    this.prototype.name = 'Winston';
  }

  constructor() {
    super();
    this.winston = require('winston');
  }

  get(category) {
    let logger = null;
    if (category) {
      logger = new Logger(this.winston.loggers.add(category, {
        console: {
          level: 'silly',
          colorize: true
        }
      }));
    } else {
      logger = this.winston;
    }
    return logger;
  }

  middleware(opts) {
    this.expressWinston = require('express-winston');
    if ((opts ? opts.winston.type : undefined) === 'error') {
      return this.expressWinston.errorLogger({
        transports: [new this.winston.transports.Console({
          json: true,
          colorize: true
        })] });
    }
    if ((opts ? opts.winston.type : undefined) === 'request') {
      return this.expressWinston.logger({
        transports: [new this.winston.transports.Console({
          json: true,
          colorize: true
        })] });
    }
  }
}
Winston.initClass();

class Caterpillar extends Library {
  static initClass() {

    this.prototype.name = 'Caterpillar';
  }

  constructor() {
    super();
    this.caterpillar = require('caterpillar');
  }

  get(category) {
    return new Logger(new this.caterpillar.Logger());
  }
}
Caterpillar.initClass();

class Tracer extends Library {

  constructor() {
    super();
    this.tracer = require('tracer');
  }

  get(category) {
    return new Logger(this.tracer.colorConsole());
  }
}

defaultExport.Logule = Logule;
defaultExport.Log4js = Log4js;
defaultExport.Winston = Winston;
defaultExport.Caterpillar = Caterpillar;
defaultExport.Tracer = Tracer;
exports.default = defaultExport;
//# sourceMappingURL=onelog.js.map
