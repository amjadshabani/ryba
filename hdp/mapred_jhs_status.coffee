
lifecycle = require './lib/lifecycle'
module.exports = []

module.exports.push (ctx) ->
  require('./mapred').configure ctx

module.exports.push name: 'HDP JobHistoryServer # Status', callback: (ctx, next) ->
  lifecycle.jhs_status ctx, (err, running) ->
    next err, if running then 'STARTED' else 'STOPPED'