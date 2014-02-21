
lifecycle = require './lib/lifecycle'
module.exports = []

module.exports.push (ctx) ->
  # require('./hdfs').configure ctx
  require('./yarn').configure ctx
  require('./mapred').configure ctx

module.exports.push name: 'HDP # Start ResourceManager', callback: (ctx, next) ->
  return next() unless ctx.has_module 'histi/hdp/yarn_rm'
  lifecycle.rm_start ctx, (err, started) ->
    next err, if started then ctx.OK else ctx.PASS

module.exports.push name: 'HDP # Start NodeManager', callback: (ctx, next) ->
  return next() unless ctx.has_module 'histi/hdp/yarn_nm'
  lifecycle.nm_start ctx, (err, started) ->
    next err, if started then ctx.OK else ctx.PASS

module.exports.push name: 'HDP # Start MapReduce HistoryServer', callback: (ctx, next) ->
  return next() unless ctx.has_module 'histi/hdp/mapred_jhs'
  lifecycle.jhs_start ctx, (err, started) ->
    next err, if started then ctx.OK else ctx.PASS


