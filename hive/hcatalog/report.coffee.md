
# Hive HCatalog Info

Retrieve various info about the HCatalog Server and the Hive Server2.

    module.exports = []
    module.exports.push 'masson/bootstrap'
    module.exports.push 'masson/bootstrap/report'
    module.exports.push 'ryba/hive/hcatalog/wait'
    # module.exports.push require('./index').configure

## Info FS Roots

List the current FS root locations for the Hive databases.

    module.exports.push name: 'Hive HCatalog # Info FS Roots', timeout: -1, label_true: 'INFO', handler: ->
      @execute
        cmd: mkcmd.hdfs , "hive --service metatool -listFSRoot 2>/dev/nul"
      , (err, _, stdout) ->
        return if err
        count = 0
        for line in string.lines stdout
          continue unless /^hdfs:\/\//.test line
          @emit 'report', key: "FS Root #{++count}", value: line

## Dependencies

    mkcmd = require '../../lib/mkcmd'
    string = require 'mecano/lib/misc/string'
