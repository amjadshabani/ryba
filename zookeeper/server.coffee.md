---
title: 
layout: module
---

# Zookeeper

    lifecycle = require '../hadoop/lib/lifecycle'
    quote = require 'regexp-quote'
    module.exports = []
    module.exports.push 'masson/bootstrap/'
    module.exports.push 'masson/bootstrap/utils'
    module.exports.push 'masson/core/yum'
    module.exports.push 'masson/core/iptables'
    module.exports.push 'masson/commons/java'
    # module.exports.push 'ryba/hadoop/core'

## Configure

*   `zookeeper_user` (object|string)   
    The Unix Zookeeper login name or a user object (see Mecano User documentation).   

```json
{
  "hdp": {
    "zookeeper_user": {
      "name": "zookeeper", "system": true, "gid": "hadoop",
      "comment": "Zookeeper User", "home": "/var/lib/zookeeper"
    }
  }
}

Example :

    module.exports.push module.exports.configure = (ctx) ->
      require('masson/core/iptables').configure ctx
      require('masson/commons/java').configure ctx
      require('./client').configure ctx
      {java_home} = ctx.config.java
      # Environnment
      {zookeeper_conf_dir, zookeeper_log_dir, zookeeper_pid_dir} = ctx.config.hdp
      ctx.config.hdp.zookeeper_env ?= {}
      ctx.config.hdp.zookeeper_env['JAVA_HOME'] ?= "#{java_home}"
      ctx.config.hdp.zookeeper_env['ZOO_LOG_DIR'] ?= "#{zookeeper_log_dir}"
      ctx.config.hdp.zookeeper_env['ZOOPIDFILE'] ?= "#{zookeeper_pid_dir}/zookeeper_server.pid"
      ctx.config.hdp.zookeeper_env['SERVER_JVMFLAGS'] ?= "-Djava.security.auth.login.config=#{zookeeper_conf_dir}/zookeeper-server.jaas"
      ctx.config.hdp.zookeeper_env['CLIENT_JVMFLAGS'] ?= "-Djava.security.auth.login.config=#{zookeeper_conf_dir}/zookeeper-client.jaas"
      # Internal
      ctx.config.hdp.zookeeper_myid ?= null

## Users & Groups

By default, the "zookeeper" package create the following entries:

```bash
cat /etc/passwd | grep zookeeper
zookeeper:x:497:498:ZooKeeper:/var/run/zookeeper:/bin/bash
cat /etc/group | grep hadoop
hadoop:x:498:hdfs
```

    module.exports.push name: 'HDP ZooKeeper # Users & Groups', callback: (ctx, next) ->
      {zookeeper_group, hadoop_group, zookeeper_user} = ctx.config.hdp
      ctx.group [zookeeper_group, hadoop_group], (err, gmodified) ->
        return next err if err
        ctx.user zookeeper_user, (err, umodified) ->
          next err, if gmodified or umodified then ctx.OK else ctx.PASS

## IPTables

| Service    | Port | Proto  | Parameter          |
|------------|------|--------|--------------------|
| zookeeper  | 2181 | tcp    | hdp.zookeeper_port |
| zookeeper  | 2888 | tcp    | -                  |
| zookeeper  | 3888 | tcp    | -                  |

IPTables rules are only inserted if the parameter "iptables.action" is set to 
"start" (default value).

    module.exports.push name: 'HDP ZooKeeper # IPTables', callback: (ctx, next) ->
      {zookeeper_port} = ctx.config.hdp
      ctx.iptables
        rules: [
          { chain: 'INPUT', jump: 'ACCEPT', dport: zookeeper_port, protocol: 'tcp', state: 'NEW', comment: "Zookeeper Client" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: 2888, protocol: 'tcp', state: 'NEW', comment: "Zookeeper Peer" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: 3888, protocol: 'tcp', state: 'NEW', comment: "Zookeeper Leader" }
        ]
        if: ctx.config.iptables.action is 'start'
      , (err, configured) ->
        next err, if configured then ctx.OK else ctx.PASS

## Install

Follow the [HDP recommandations][install] to install the "zookeeper" package
which has no dependency.

    module.exports.push name: 'HDP ZooKeeper # Install', timeout: -1, callback: (ctx, next) ->
      ctx.service name: 'zookeeper', (err, serviced) ->
        next err, if serviced then ctx.OK else ctx.PASS

## Startup

Install and configure the startup script in 
"/etc/init.d/zookeeper-server".

    module.exports.push name: 'HDP HDFS Zookeeper # Startup', callback: (ctx, next) ->
      {hdfs_pid_dir} = ctx.config.hdp
      modified = false
      do_install = ->
        ctx.service
          name: 'zookeeper-server'
          startup: true
        , (err, serviced) ->
          return next err if err
          modified = true if serviced
          do_fix()
      do_fix = ->
        ctx.write
          destination: '/etc/init.d/zookeeper-server'
          match: /^(\. .*\/bigtop-detect-javahome)$/m
          replace: "#$1"
        , (err, written) ->
          return next err if err
          modified = true if written
          do_end()
      do_end = ->
        next null, if modified then ctx.OK else ctx.PASS
      do_install()

    module.exports.push name: 'HDP ZooKeeper # Kerberos', timeout: -1, callback: (ctx, next) ->
      {zookeeper_user, hadoop_group, realm, zookeeper_conf_dir} = ctx.config.hdp
      {kadmin_principal, kadmin_password, admin_server} = ctx.config.krb5.etc_krb5_conf.realms[realm]
      modified = false
      do_principal = ->
        ctx.krb5_addprinc
          principal: "zookeeper/#{ctx.config.host}@#{realm}"
          randkey: true
          keytab: "#{zookeeper_conf_dir}/zookeeper.keytab"
          uid: zookeeper_user.name
          gid: hadoop_group.name
          kadmin_principal: kadmin_principal
          kadmin_password: kadmin_password
          kadmin_server: admin_server
        , (err, created) ->
          return next err if err
          modified = true if created
          do_server_jaas()
      do_server_jaas = ->
        ctx.write
          destination: '/etc/zookeeper/conf/zookeeper-server.jaas'
          content: """
          Server {
            com.sun.security.auth.module.Krb5LoginModule required
            useKeyTab=true
            storeKey=true
            useTicketCache=false
            keyTab="#{zookeeper_conf_dir}/zookeeper.keytab"
            principal="zookeeper/#{ctx.config.host}@#{realm}";
          };
          """
        , (err, written) ->
          next err if err
          modified = true if written
          do_client_jaas()
      do_client_jaas = ->
        ctx.write
          destination: "#{zookeeper_conf_dir}/zookeeper-client.jaas"
          content: """
          Client {
            com.sun.security.auth.module.Krb5LoginModule required
            useKeyTab=false
            useTicketCache=true;
          };
          """
        , (err, written) ->
          next err if err
          modified = true if written
          do_end()
      do_end = ->
        next null, if modified then ctx.OK else ctx.PASS
      do_principal()

    module.exports.push name: 'HDP ZooKeeper # Layout', callback: (ctx, next) ->
      { hadoop_group, zookeeper_user, 
        zookeeper_data_dir, zookeeper_pid_dir, zookeeper_log_dir
      } = ctx.config.hdp
      ctx.mkdir [
        destination: zookeeper_data_dir
        uid: zookeeper_user.name
        gid: hadoop_group.name
        mode: 0o755
      ,
        destination: zookeeper_pid_dir
        uid: zookeeper_user.name
        gid: hadoop_group.name
        mode: 0o755
      ,
        destination: zookeeper_log_dir
        uid: zookeeper_user.name
        gid: hadoop_group.name
        mode: 0o755
      ], (err, modified) ->
        next err, if modified then ctx.OK else ctx.PASS

    module.exports.push name: 'HDP ZooKeeper # Environment', callback: (ctx, next) ->
      {zookeeper_conf_dir, zookeeper_env} = ctx.config.hdp
      write = for k, v of zookeeper_env
        match: RegExp "^export\\s+(#{quote k})=(.*)$", 'mg'
        replace: "export #{k}=#{v}"
        append: true
      ctx.write
        destination: "#{zookeeper_conf_dir}/zookeeper-env.sh"
        write: write
        backup: true
      , (err, written) ->
        return next err, if written then ctx.OK else ctx.PASS

    module.exports.push name: 'HDP ZooKeeper # Configure', callback: (ctx, next) ->
      modified = false
      hosts = ctx.hosts_with_module 'ryba/zookeeper/server'
      { hadoop_group, zookeeper_user,
        zookeeper_conf_dir, zookeeper_data_dir,
        zookeeper_myid, zookeeper_port
      } = ctx.config.hdp
      do_zoo_cfg = ->
        mapping = (for host, i in hosts
          "server.#{i+1}=#{host}:2888:3888").join '\n'
        ctx.write
          content: """
          # The number of milliseconds of each tick
          tickTime=2000
          # The number of ticks that the initial
          # synchronization phase can take
          initLimit=10
          # The number of ticks that can pass between
          # sending a request and getting an acknowledgement
          syncLimit=5
          # the directory where the snapshot is stored.
          dataDir=#{zookeeper_data_dir}
          # the port at which the clients will connect
          clientPort=#{zookeeper_port}
          #{mapping}
          # SASL
          authProvider.1=org.apache.zookeeper.server.auth.SASLAuthenticationProvider
          jaasLoginRenew=3600000
          kerberos.removeHostFromPrincipal=true
          kerberos.removeRealmFromPrincipal=true 
          """
          destination: "#{zookeeper_conf_dir}/zoo.cfg"
        , (err, written) ->
          return next err if err
          modified = true if written
          do_myid()
      do_myid = ->
        unless zookeeper_myid
          for host, i in hosts
            zookeeper_myid = i+1 if host is ctx.config.host
        ctx.log 'Write myid'
        ctx.write
          content: zookeeper_myid
          destination: "#{zookeeper_data_dir}/myid"
          uid: zookeeper_user.name
          gid: hadoop_group.name
        , (err, written) ->
          return next err if err
          modified = true if written
          do_end()
      do_end = ->
        next null, if modified then ctx.OK else ctx.PASS
      do_zoo_cfg()

    module.exports.push name: 'HDP ZooKeeper # Start', timeout: -1, callback: (ctx, next) ->
      lifecycle.zookeeper_start ctx, (err, started) ->
        next err, if started then ctx.OK else ctx.PASS

    module.exports.push 'ryba/zookeeper/server_check'

## Resources

*   [ZooKeeper Resilience](http://blog.cloudera.com/blog/2014/03/zookeeper-resilience-at-pinterest/)

[install]: http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.1-latest/bk_installing_manually_book/content/rpm-zookeeper-1.html



