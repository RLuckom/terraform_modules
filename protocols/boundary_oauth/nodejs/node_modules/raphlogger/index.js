function init(output, options) {
  const levels = {
    ERROR: 'ERROR',
    WARN: 'WARN',
    INFO: 'INFO',
    DEBUG: 'DEBUG',
    TRACE: 'TRACE',
  }
  const priorities = {
    ERROR: 0,
    WARN: 1,
    INFO: 2,
    DEBUG: 3,
    TRACE: 4,
  }

  let source = sourceInstance = component = asyncOutput = level = priority = undefined
  if (options) {
    source = options.source
    level = options.level || levels.WARN
    priority = priorities[level]
    sourceInstance = options.sourceInstance
    component = options.component
    asyncOutput = options.asyncOutput
  }
  output = output || ((args) => console.log(JSON.stringify(args)))
  function isStringOrUnset(s) {
    return !s || typeof s === 'string'
  }
  function isString(s) {
    return typeof s === 'string'
  }
  function isPrimitive(test) {
    return test !== Object(test);
  }
  function isStringArrayOrUnset(sa) {
    if (sa) {
      return isStringArray(sa)
    }
    return true
  }
  function isPrimitiveMapOrUnset(sm) {
    if (sm) {
      return isPrimitiveMap(sm)
    }
    return true
  }
  function isStringArray(sa) {
    if (!Array.isArray(sa)) {
      return false
    }
    let allStrings = true
    for (s of sa) {
      allStrings = allStrings && isString(s)
      if (!allStrings) {
        return allStrings
      }
    }
    return allStrings
  }
  function isPrimitiveMap(sm) {
    if (typeof sm !== 'object' || sm === null) {
      return false
    }
    valid = true
    for (key in sm) {
      const val = sm[key]
      valid = valid && isString(key) && isPrimitive(val)
      if (!valid) {
        return valid
      }
    }
    return valid
  }
  function assert(valid, name, expected, value) {
    if (!valid) {
      log({level: levels.ERROR, tags: ["INVALID_LOG"], component: 'logger', metadata: {name, expected, value: String(value)} })
      return undefined
    }
    return value
  }
  function validateLogArgs(args) {
    return {
      stack: assert(isStringOrUnset(args.stack), 'stack', 'string', args.stack),
      level: assert(levels[args.level], 'level', 'level', args.level) || levels.ERROR,
      tags: assert(isStringArrayOrUnset(args.tags), 'tags', 'stringArray', args.tags) || [],
      metadata: assert(isPrimitiveMapOrUnset(args.metadata), 'metadata', 'primitiveMap', args.metadata) || {},
    }
  }
  function log(args) {
    const defaults = {source, sourceInstance, component}
    args = validateLogArgs(args)
    if (priorities[args.level] > priority) {
      return
    }
    if (args.level === levels.ERROR || args.level === levels.WARN && !args.stack) {
      args.stack = new Error().stack
    }
    output({...defaults, ...validateLogArgs(args), ...{timestamp: new Date().toISOString()}})
  }
  function asyncLog(args, callback) {
    args = validateLogArgs(args)
    if (!priorities[args.level] > priority) {
      return
    }
    if (args.level === levels.ERROR || args.level === levels.WARN && !args.stack) {
      args.stack = new Error().stack
    }
    output({...{source, sourceInstance, component}, ...args}, callback)
  }
  function setSource(s) {
    if (assert(isString(s), 'source', 'string', s)) {
      source = s
    }
  }
  function setSourceInstance(si) {
    if (assert(isString(si), 'sourceInstance', 'string', si)) {
      sourceInstance = si
    }
  }
  function setComponent(c) {
    if (assert(isString(c), 'component', 'string', c)) {
      component = c
    }
  }
  function convertString(args) {
    if (typeof args === "string") {
      return {
        metadata: {
          message: args
        }
      }
    }
    return args
  }
  log.levels = levels
  asyncLog.levels = levels
  const selectedLogger = asyncOutput ? asyncLog : log
  const error = (args, callback) => {
    args = convertString(args)
    args.level = levels.ERROR
    selectedLogger(args, callback)
  }
  const warn = (args, callback) => {
    args = convertString(args)
    args.level = levels.WARN
    selectedLogger(args, callback)
  }
  const info = (args, callback) => {
    args = convertString(args)
    args.level = levels.INFO
    selectedLogger(args, callback)
  }
  const debug = (args, callback) => {
    args = convertString(args)
    args.level = levels.DEBUG
    selectedLogger(args, callback)
  }
  const trace = (args, callback) => {
    args = convertString(args)
    args.level = levels.TRACE
    selectedLogger(args, callback)
  }
  return {
    log: asyncOutput ? asyncLog : log,
    error,
    warn,
    info,
    debug,
    trace,
    setSource,
    setSourceInstance,
    setComponent,
  }
}

module.exports = {
  init
}
