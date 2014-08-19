---
title: 
layout: module
---

# Ganglia Monitor Start

Execute these commands on the Ganglia server host machine.

    module.exports = []
    module.exports.push 'masson/bootstrap/connection'
    module.exports.push 'masson/bootstrap/mecano'

    module.exports.push name: 'Ganglia Collector # Start', callback: (ctx, next) ->
      ctx.service [
      #   name: 'httpd'
      #   action: 'start'
      # ,
        # name: 'ganglia-gmetad-3.5.0-99'
        srv_name: 'hdp-gmetad'
        action: 'start'
      ], (err, stoped) ->
        next err, if stoped then ctx.OK else ctx.PASS