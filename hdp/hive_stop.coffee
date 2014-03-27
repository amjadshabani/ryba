
lifecycle = require './lib/lifecycle'
module.exports = []
module.exports.push 'phyla/bootstrap'

module.exports.push (ctx) ->
  require('./core').configure ctx
  require('./hive_server').configure ctx

###
Stop Server2
-------------
Execute these commands on the Hive Server2 host machine.
###
module.exports.push name: 'HDP # Stop Hive Server2', callback: (ctx, next) ->
  {hive_user, hive_log_dir} = ctx.config.hdp
  lifecycle.hive_server2_stop ctx, (err, stopped) ->
    next err, ctx.OK

###
Stop Hive Metastore
--------------------
Execute these commands on the Hive Metastore host machine.
###
module.exports.push name: 'HDP # Stop Hive Metastore', callback: (ctx, next) ->
  {hive_user, hive_log_dir} = ctx.config.hdp
  lifecycle.hive_metastore_stop ctx, (err, stopped) ->
    next err, ctx.OK

