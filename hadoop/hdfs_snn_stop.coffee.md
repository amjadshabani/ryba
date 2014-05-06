---
title: 
layout: module
---

# HDFS SecondaryNameNode Stop

    lifecycle = require './lib/lifecycle'
    module.exports = []
    module.exports.push 'masson/bootstrap/'

    module.exports.push (ctx) ->
      require('./hdfs').configure ctx

    module.exports.push name: 'HDP HDFS SNN # Stop', callback: (ctx, next) ->
      return next new Error "Not an Secondary NameNode" unless ctx.has_module 'phyla/hadoop/hdfs_snn'
      lifecycle.snn_stop ctx, (err, stopped) ->
        next err, if stopped then ctx.OK else ctx.PASS