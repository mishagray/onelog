exports = module.exports

exports.setup = (callback) ->

  {write} = process.stdout

  fn = (stub) ->
    (string, encoding, fd) ->
      stub.apply process.stdout, arguments
      callback string, encoding, fd
  fn process.stdout.write

  process.stdout.write = fn

  unhook = -> process.stdout.write = write

  return unhook
