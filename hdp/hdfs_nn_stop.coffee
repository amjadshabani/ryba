
lifecycle = require './lib/lifecycle'
module.exports = []
module.exports.push 'phyla/bootstrap'

module.exports.push (ctx) ->
  require('./hdfs').configure ctx
  require('./yarn').configure ctx
  require('./mapred').configure ctx
  throw Error "Not a NameNode" unless ctx.has_module 'phyla/hdp/hdfs_nn'

module.exports.push name: 'HDP HDFS NN # Stop ZKFC', callback: (ctx, next) ->
  lifecycle.zkfc_stop ctx, (err, stopped) ->
    next err, if stopped then ctx.OK else ctx.PASS

module.exports.push name: 'HDP HDFS NN # Stop NameNode', callback: (ctx, next) ->
  lifecycle.nn_stop ctx, (err, stopped) ->
    next err, if stopped then ctx.OK else ctx.PASS
