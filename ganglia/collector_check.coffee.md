---
title: Ganglia Collector
module: ryba/ganglia/collector_check
layout: module
---

# Check Ganglia Collector

    module.exports = []
    module.exports.push 'masson/bootstrap/'

## Check Services

Call the "checkGmetad.sh" deployed by the Ganglia HDP package and check if the
"/usr/bin/rrdcached" and "/usr/sbin/gmetad" daemons are running.

    module.exports.push name: 'Ganglia Collector # Check Services', callback: (ctx, next) ->
      ctx.execute
        cmd: "/usr/libexec/hdp/ganglia/checkGmetad.sh"
      , (err, running) ->
        next err, ctx.STABLE
