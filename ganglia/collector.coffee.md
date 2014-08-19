---
title: Ganglia Collector
module: ryba/ganglia/collector
layout: module
---

# Ganglia Collector

Ganglia Collector is the server which recieve data collected on each 
host by the Ganglia Monitor agents.

    module.exports = []
    module.exports.push 'masson/bootstrap/'
    module.exports.push 'masson/core/yum'
    module.exports.push 'masson/core/iptables'
    module.exports.push 'masson/commons/httpd'

## Configure

*   `rrdcached_user` (object|string)   
    The Unix RRDtool login name or a user object (see Mecano User documentation).   
*   `rrdcached_group` (object|string)   
    The Unix Hue group name or a group object (see Mecano Group documentation).   

Example:

```json
{
  "ganglia": {
    "rrdcached_user": {
      "name": "rrdcached", "system": true, "gid": "rrdcached", "shell": false
      "comment": "RRDtool User", "home": "/usr/lib/rrdcached"
    }
    "rrdcached_group": {
      "name": "Hue", "system": true
    }
  }
}
```

    module.exports.push module.exports.configure = (ctx) ->
      require('masson/core/iptables').configure ctx
      ctx.config.hdp ?= {}
      ctx.config.hdp.rrdcached_user = name: ctx.config.hdp.rrdcached_user if typeof ctx.config.hdp.rrdcached_user is 'string'
      ctx.config.hdp.rrdcached_user ?= {}
      ctx.config.hdp.rrdcached_user.name ?= 'rrdcached'
      ctx.config.hdp.rrdcached_user.system ?= true
      ctx.config.hdp.rrdcached_user.gid = 'rrdcached'
      ctx.config.hdp.rrdcached_user.shell = false
      ctx.config.hdp.rrdcached_user.comment ?= 'RRDtool User'
      ctx.config.hdp.rrdcached_user.home = '/var/rrdtool/rrdcached'
      # Group
      ctx.config.hdp.rrdcached_group = name: ctx.config.hdp.rrdcached_group if typeof ctx.config.hdp.rrdcached_group is 'string'
      ctx.config.hdp.rrdcached_group ?= {}
      ctx.config.hdp.rrdcached_group.name ?= 'rrdcached'
      ctx.config.hdp.rrdcached_group.system ?= true

## Users & Groups

By default, the "rrdcached" package create the following entries:

```bash
cat /etc/passwd | grep rrdcached
rrdcached:x:493:493:rrdcached:/var/rrdtool/rrdcached:/sbin/nologin
cat /etc/group | grep rrdcached
rrdcached:x:493:
```

    module.exports.push name: 'Ganglia Collector # Users & Groups', callback: (ctx, next) ->
      {rrdcached_group, rrdcached_user} = ctx.config.hdp
      ctx.group rrdcached_group, (err, gmodified) ->
        return next err if err
        ctx.user rrdcached_user, (err, umodified) ->
          next err, if gmodified or umodified then ctx.OK else ctx.PASS

## IPTables

| Service          | Port  | Proto | Info                     |
|------------------|-------|-------|--------------------------|
| ganglia-gmetad   | 8649 | http   | Ganglia Collector server |
| hdp-gmetad   | 8660 |   | Ganglia Collector HDPSlaves |
| hdp-gmetad   | 8661 |   | Ganglia Collector HDPNameNode |
| hdp-gmetad   | 8663 |   | Ganglia Collector HDPHBaseMaster |
| hdp-gmetad   | 8664 |   | Ganglia Collector HDPResourceManager |
| hdp-gmetad   | 8666 |   | Ganglia Collector HDPHistoryServer |

IPTables rules are only inserted if the parameter "iptables.action" is set to 
"start" (default value).

    module.exports.push name: 'Ganglia Collector # IPTables', callback: (ctx, next) ->
      ctx.iptables
        rules: [
          { chain: 'INPUT', jump: 'ACCEPT', dport: 8649, protocol: 'tcp', state: 'NEW', comment: "Ganglia Collector Server" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: 8660, protocol: 'tcp', state: 'NEW', comment: "Ganglia Collector HDPSlaves" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: 8661, protocol: 'tcp', state: 'NEW', comment: "Ganglia Collector HDPNameNode" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: 8663, protocol: 'tcp', state: 'NEW', comment: "Ganglia Collector HDPHBaseMaster" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: 8664, protocol: 'tcp', state: 'NEW', comment: "Ganglia Collector HDPResourceManager" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: 8666, protocol: 'tcp', state: 'NEW', comment: "Ganglia Collector HDPHistoryServer" }
        ]
        if: ctx.config.iptables.action is 'start'
      , (err, configured) ->
        next err, if configured then ctx.OK else ctx.PASS

## Service

The packages "ganglia-gmetad-3.5.0-99" and "ganglia-web-3.5.7-99" are installed.

    module.exports.push name: 'Ganglia Collector # Service', timeout: -1, callback: (ctx, next) ->
      ctx.service [
        name: 'ganglia-gmetad-3.5.0-99'
        chk_name: 'gmetad'
        startup: false
      ,
        name: 'ganglia-web-3.5.7-99'
      ], (err, serviced) ->
        next err, if serviced then ctx.OK else ctx.PASS

## Layout

We prepare the directory "/usr/libexec/hdp/ganglia" in which we later upload
the objects files and generate the hosts configuration.

    module.exports.push name: 'Ganglia Collector # Layout', timeout: -1, callback: (ctx, next) ->
      ctx.mkdir
        destination: '/usr/libexec/hdp/ganglia'
      , (err, created) ->
        next err, if created then ctx.OK else ctx.PASS

## Objects

Copy the object files provided in the HDP companion files into the 
"/usr/libexec/hdp/ganglia" folder. Permissions on those file are set to "0o744".

    module.exports.push name: 'Ganglia Collector # Objects', timeout: -1, callback: (ctx, next) ->
      glob "#{__dirname}/../hadoop/files/ganglia/objects/*.*", (err, files) ->
        files = for file in files then source: file, destination: "/usr/libexec/hdp/ganglia", mode: 0o744
        ctx.upload files, (err, uploaded) ->
          next err, if uploaded then ctx.OK else ctx.PASS

## Init Script

Upload the "hdp-gmetad" service file into "/etc/init.d".

    module.exports.push name: 'Ganglia Collector # Init Script', timeout: -1, callback: (ctx, next) ->
      ctx.upload [
        source: "#{__dirname}/../hadoop/files/ganglia/scripts/hdp-gmetad"
        destination: '/etc/init.d'
        mode: 0o755
      ], (err, uploaded) ->
        next err, if uploaded then ctx.OK else ctx.PASS

## Fix RRD

There is a first bug in the HDP companion files preventing RRDtool (thus
Ganglia) from starting. The variable "RRDCACHED_BASE_DIR" should point to 
"/var/lib/ganglia/rrds".

    module.exports.push name: 'Ganglia Collector # Fix RRD', callback: (ctx, next) ->
      ctx.write
        destination: '/usr/libexec/hdp/ganglia/gangliaLib.sh'
        match: /^RRDCACHED_BASE_DIR=.*$/mg
        replace: 'RRDCACHED_BASE_DIR=/var/lib/ganglia/rrds;'
        append: 'GANGLIA_RUNTIME_DIR'
      , (err, written) ->
        next err, if written then ctx.OK else ctx.PASS

# ## Fix permission

# The message "error collecting ganglia data (127.0.0.1:8652): fsockopen error"
# appeared on one cluster. Another cluster installed at the same time seems
# correct.

#     module.exports.push name: 'Ganglia Collector # Fix permission', callback: (ctx, next) ->
#       ctx.execute
#         cmd: 'chown -R nobody:root /var/lib/ganglia/rrds'
#       , (err, written) ->
#         next err, ctx.PASS

## Fix User

RRDtool is by default runing as "nobody". In order to work, nobody need a login shell
in its user account definition.

    module.exports.push name: 'Ganglia Collector # Fix User', callback: (ctx, next) ->
      ctx.execute
        cmd: 'usermod -s /bin/bash nobody'
      , (err, executed, stdout, stderr) ->
        next err, if /no changes/.test(stdout) then ctx.PASS else ctx.OK

## Clusters

The cluster generation follow Hortonworks guideline and generate the clusters 
"HDPHistoryServer", "HDPNameNode", "HDPResourceManager", "HDPSlaves" and "HDPHBaseMaster".

    module.exports.push name: 'Ganglia Collector # Clusters', timeout: -1, callback: (ctx, next) ->
      cmds = []
      # On the Ganglia server, to configure the gmond collector
      cmds.push 
        cmd: "/usr/libexec/hdp/ganglia/setupGanglia.sh -c HDPHistoryServer -m"
        not_if_exists: '/etc/ganglia/hdp/HDPHistoryServer'
      cmds.push
        cmd: "/usr/libexec/hdp/ganglia/setupGanglia.sh -c HDPNameNode -m"
        not_if_exists: '/etc/ganglia/hdp/HDPNameNode'
      cmds.push
        cmd: "/usr/libexec/hdp/ganglia/setupGanglia.sh -c HDPResourceManager -m"
        not_if_exists: '/etc/ganglia/hdp/HDPResourceManager'
      cmds.push
        cmd: "/usr/libexec/hdp/ganglia/setupGanglia.sh -c HDPSlaves -m"
        not_if_exists: '/etc/ganglia/hdp/HDPSlaves'
      cmds.push
        cmd: "/usr/libexec/hdp/ganglia/setupGanglia.sh -c HDPHBaseMaster -m"
        not_if_exists: '/etc/ganglia/hdp/HDPHBaseMaster'
      cmds.push
        cmd: "/usr/libexec/hdp/ganglia/setupGanglia.sh -t"
        not_if_exists: '/etc/ganglia/hdp/gmetad.conf'
      ctx.execute cmds, (err, executed) ->
        next err, if executed then ctx.OK else ctx.PASS

## Configuration

In order to work properly, each cluster must be updated with the "bind" property 
pointing to the Ganglia master hostname.

    module.exports.push name: 'Ganglia Collector # Configuration', callback: (ctx, next) ->
      ctx.write [
        destination: "/etc/ganglia/hdp/HDPNameNode/conf.d/gmond.master.conf"
        match: /^(.*)bind = (.*)$/mg
        replace: "$1bind = #{ctx.config.host}"
      ,
        destination: "/etc/ganglia/hdp/HDPHistoryServer/conf.d/gmond.master.conf"
        match: /^(.*)bind = (.*)$/mg
        replace: "$1bind = #{ctx.config.host}"
      ,
        destination: "/etc/ganglia/hdp/HDPResourceManager/conf.d/gmond.master.conf"
        match: /^(.*)bind = (.*)$/mg
        replace: "$1bind = #{ctx.config.host}"
      ,
        destination: "/etc/ganglia/hdp/HDPSlaves/conf.d/gmond.master.conf"
        match: /^(.*)bind = (.*)$/mg
        replace: "$1bind = #{ctx.config.host}"
      ,
        destination: "/etc/ganglia/hdp/HDPHBaseMaster/conf.d/gmond.master.conf"
        match: /^(.*)bind = (.*)$/mg
        replace: "$1bind = #{ctx.config.host}"
      ,
        destination: "/etc/ganglia/hdp/gmetad.conf"
        match: /^(data_source.* )(.*):(\d+)$/mg
        replace: "$1#{ctx.config.host}:$3"
      ], (err, written) ->
        next err, if written then ctx.OK else ctx.PASS

## HTTPD Restart

    module.exports.push name: 'Ganglia Collector # HTTPD Restart', callback: (ctx, next) ->
      ctx.service
        srv_name: 'httpd'
        action: 'restart'
        not_if: (callback) ->
          request "http://#{ctx.config.host}/ganglia", (err, _, body) ->
            callback err, /Ganglia Web Frontend/.test body
      , (err, restarted) ->
        next err, if restarted then ctx.OK else ctx.PASS

## Start

    module.exports.push 'ryba/ganglia/collector_start'

## Check

    module.exports.push 'ryba/ganglia/collector_check'

## Module dependencies

    request = require 'request'
    glob = require 'glob'




