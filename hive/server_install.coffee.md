---
title: 
layout: module
---

# Hive Server Install

    module.exports = []
    module.exports.push 'masson/bootstrap/'
    module.exports.push 'masson/bootstrap/utils'
    module.exports.push 'masson/core/krb5_client'
    module.exports.push 'masson/core/iptables'
    module.exports.push 'masson/commons/mysql_client' # Install the mysql connector
    module.exports.push 'ryba/hadoop/core' # Configure "core-site.xml" and "hadoop-env.sh"
    module.exports.push 'ryba/hive/_' # Install the Hive and HCatalog service

    module.exports.push require('./server').configure

## IPTables

| Service        | Port  | Proto | Parameter            |
|----------------|-------|-------|----------------------|
| Hive Metastore | 9083  | http  | hive.metastore.uris  |
| Hive Web UI    | 9999  | http  | hive.hwi.listen.port |
| Hive Server    | 10001 | tcp   | env[HIVE_PORT]       |


IPTables rules are only inserted if the parameter "iptables.action" is set to 
"start" (default value).

    module.exports.push name: 'Hive & HCat Server # IPTables', callback: (ctx, next) ->
      {hive_site} = ctx.config.ryba
      hive_server_port = if hive_site['hive.server2.transport.mode'] is 'binary'
      then hive_site['hive.server2.thrift.port']
      else hive_site['hive.server2.thrift.http.port']
      ctx.iptables
        rules: [
          { chain: 'INPUT', jump: 'ACCEPT', dport: 9083, protocol: 'tcp', state: 'NEW', comment: "Hive Metastore" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: 9999, protocol: 'tcp', state: 'NEW', comment: "Hive Web UI" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: hive_server_port, protocol: 'tcp', state: 'NEW', comment: "Hive Server" }
        ]
        if: ctx.config.iptables.action is 'start'
      , next

## Startup

Install and configure the startup script in "/etc/init.d/hive-hcatalog-server"
and "/etc/init.d/hive-server2".

    module.exports.push name: 'Hive & HCat Server # Startup', callback: (ctx, next) ->
      ctx.service [
        name: 'hive-hcatalog-server'
        startup: true
      ,
        name: 'hive-server2'
        startup: true
      ], next

    module.exports.push name: 'Hive & HCat Server # Fix Startup', callback: (ctx, next) ->
      ctx.write [
        destination: '/etc/init.d/hive-hcatalog-server'
        match: /^.*# Ryba: clean pidfile if pid not running$/m
        replace: """
        if pid=`cat $PIDFILE`; then if ! ps -e -o pid | grep -v grep | grep -w $pid; then rm $PIDFILE; fi; fi; \# Ryba: clean pidfile if pid not running
        """
        append: /^PIDFILE=.*$/m
      ,
        destination: '/etc/init.d/hive-server2'
        match: /^.*# Ryba: clean pidfile if pid not running$/m
        replace: """
        if pid=`cat $PIDFILE`; then if ! ps -e -o pid | grep -v grep | grep -w $pid; then rm $PIDFILE; fi; fi; \# Ryba: clean pidfile if pid not running
        """
        append: /^PIDFILE=.*$/m
      ], next

    module.exports.push name: 'Hive & HCat Server # Database', callback: (ctx, next) ->
      {hive_site, db_admin} = ctx.config.ryba
      username = hive_site['javax.jdo.option.ConnectionUserName']
      password = hive_site['javax.jdo.option.ConnectionPassword']
      {engine, db} = parse_jdbc hive_site['javax.jdo.option.ConnectionURL']
      engines = 
        mysql: ->
          escape = (text) -> text.replace(/[\\"]/g, "\\$&")
          cmd = "#{db_admin.path} -u#{db_admin.username} -p#{db_admin.password} -h#{db_admin.host} -P#{db_admin.port} -e "
          ctx.execute
            cmd: """
            if #{cmd} "use #{db}"; then exit 2; fi
            #{cmd} "
            create database if not exists #{db};
            grant all privileges on #{db}.* to '#{username}'@'localhost' identified by '#{password}';
            grant all privileges on #{db}.* to '#{username}'@'%' identified by '#{password}';
            flush privileges;
            "
            """
            code_skipped: 2
          , next
      return next new Error 'Database engine not supported' unless engines[engine]
      engines[engine]()

    module.exports.push name: 'Hive & HCat Server # Configure', callback: (ctx, next) ->
      {hive_site, hive_user, hive_group, hive_conf_dir} = ctx.config.ryba
      ctx.hconfigure
        destination: "#{hive_conf_dir}/hive-site.xml"
        default: "#{__dirname}/../resources/hive/hive-site.xml"
        local_default: true
        properties: hive_site
        merge: true
      , (err, configured) ->
        return next err if err
        ctx.execute
          cmd: """
          chown -R #{hive_user.name}:#{hive_group.name} #{hive_conf_dir}/
          chmod -R 755 #{hive_conf_dir}
          """
        , (err) ->
          next err, configured

    module.exports.push name: 'Hive & HCat Server # Fix', callback: (ctx, next) ->
      {hive_conf_dir} = ctx.config.ryba
      ctx.write
        destination: "#{hive_conf_dir}/hive-env.sh"
        match: /^export HIVE_AUX_JARS_PATH=.*$/mg
        replace: 'export HIVE_AUX_JARS_PATH=${HIVE_AUX_JARS_PATH:-/usr/lib/hive-hcatalog/share/hcatalog/hive-hcatalog-core.jar}'
      , next

    module.exports.push name: 'Hive & HCat Server # Libs', callback: (ctx, next) ->
      {hive_libs} = ctx.config.ryba
      return next() unless hive_libs.length
      uploads = for lib in hive_libs
        source: lib
        destination: "/usr/lib/hive/lib/#{path.basename lib}"
      ctx.upload uploads, next

    module.exports.push name: 'Hive & HCat Server # Driver', callback: (ctx, next) ->
      ctx.link
        source: '/usr/share/java/mysql-connector-java.jar'
        destination: '/usr/lib/hive/lib/mysql-connector-java.jar'
      , next

    module.exports.push name: 'Hive & HCat Server # Kerberos', callback: (ctx, next) ->
      {hive_user, hive_group, hive_site, realm} = ctx.config.ryba
      {kadmin_principal, kadmin_password, admin_server} = ctx.config.krb5.etc_krb5_conf.realms[realm]
      modified = false
      do_metastore = ->
        ctx.krb5_addprinc
          principal: hive_site['hive.metastore.kerberos.principal'].replace '_HOST', ctx.config.host
          randkey: true
          keytab: hive_site['hive.metastore.kerberos.keytab.file']
          uid: hive_user.name
          gid: hive_group.name
          kadmin_principal: kadmin_principal
          kadmin_password: kadmin_password
          kadmin_server: admin_server
        , (err, created) ->
          return next err if err
          modified = true if created
          do_server2()
      do_server2 = ->
        return do_end() if hive_site['hive.metastore.kerberos.principal'] is hive_site['hive.server2.authentication.kerberos.principal']
        ctx.krb5_addprinc
          principal: hive_site['hive.server2.authentication.kerberos.principal'].replace '_HOST', ctx.config.host
          randkey: true
          keytab: hive_site['hive.server2.authentication.kerberos.keytab']
          uid: hive_user.name
          gid: hive_group.name
          kadmin_principal: kadmin_principal
          kadmin_password: kadmin_password
          kadmin_server: admin_server
        , (err, created) ->
          return next err if err
          modified = true if created
          do_end()
      do_end = ->
        next null, modified
      do_metastore()

    module.exports.push name: 'Hive & HCat Server # Logs', callback: (ctx, next) ->
      ctx.write [
        source: "#{__dirname}/../resources/hive/hive-exec-log4j.properties.template"
        local_source: true
        destination: '/etc/hive/conf/hive-exec-log4j.properties'
      ,
        source: "#{__dirname}/../resources/hive/hive-log4j.properties.template"
        local_source: true
        destination: '/etc/hive/conf/hive-log4j.properties'
      ], next

    module.exports.push name: 'Hive & HCat Server # Layout', timeout: -1, callback: (ctx, next) ->
      {hive_user, hive_group} = ctx.config.ryba
      # Required by service "hive-hcatalog-server"
      ctx.mkdir
        destination: '/var/log/hive-hcatalog'
        uid: hive_user.name
        gid: hive_group.name
      , next

    module.exports.push name: 'Hive & HCat Server # HDFS Layout', timeout: -1, callback: (ctx, next) ->
      # todo: this isnt pretty, ok that we need to execute hdfs command from an hadoop client
      # enabled environment, but there must be a better way
      {active_nn_host, hdfs_user, hive_user, hive_group} = ctx.config.ryba
      hive_user = hive_user.name
      hive_group = hive_group.name
      # ctx.connect active_nn_host, (err, ssh) ->
      #   return next err if err
        # kerberos = true
      cmd = mkcmd.hdfs ctx, "hdfs dfs -test -d /user && hdfs dfs -test -d /apps && hdfs dfs -test -d /tmp"
      ctx.waitForExecution cmd, code_skipped: 1, (err) ->
        modified = false
        do_user = ->
          ctx.execute
            cmd: mkcmd.hdfs ctx, """
            if hdfs dfs -ls /user/#{hive_user} &>/dev/null; then exit 1; fi
            hdfs dfs -mkdir /user/#{hive_user}
            hdfs dfs -chown #{hive_user}:#{hdfs_user.name} /user/#{hive_user}
            """
            code_skipped: 1
          , (err, executed, stdout) ->
            return next err if err
            modified = true if executed
            do_warehouse()
        do_warehouse = ->
          ctx.execute
            cmd: mkcmd.hdfs ctx, """
            if hdfs dfs -ls /apps/#{hive_user}/warehouse &>/dev/null; then exit 3; fi
            hdfs dfs -mkdir /apps/#{hive_user}
            hdfs dfs -mkdir /apps/#{hive_user}/warehouse
            hdfs dfs -chown -R #{hive_user}:#{hdfs_user.name} /apps/#{hive_user}
            hdfs dfs -chmod 755 /apps/#{hive_user}
            hdfs dfs -chmod 1777 /apps/#{hive_user}/warehouse
            """
            code_skipped: 3
          , (err, executed, stdout) ->
            return next err if err
            modified = true if executed
            do_scratch()
        do_scratch = ->
          ctx.execute
            cmd: mkcmd.hdfs ctx, """
            if hdfs dfs -ls /tmp/scratch &> /dev/null; then exit 1; fi
            hdfs dfs -mkdir /tmp 2>/dev/null
            hdfs dfs -mkdir /tmp/scratch
            hdfs dfs -chown #{hive_user}:#{hdfs_user.name} /tmp/scratch
            hdfs dfs -chmod -R 1777 /tmp/scratch
            """
            code_skipped: 1
          , (err, executed, stdout) ->
            return next err if err
            modified = true if executed
            do_end()
        do_end = ->
          next null, modified
        do_warehouse()

TODO: Implement lock for Hive Server2
http://www.cloudera.com/content/cloudera-content/cloudera-docs/CDH4/4.2.0/CDH4-Installation-Guide/cdh4ig_topic_18_5.html

    module.exports.push 'ryba/hive/server_start'

    module.exports.push 'ryba/hive/server_check'

    module.exports.push name: 'Hive & HCat Server # Check', timeout: -1, callback: (ctx, next) ->
      # http://www.cloudera.com/content/cloudera-content/cloudera-docs/CDH4/4.3.0/CDH4-Security-Guide/cdh4sg_topic_9_1.html
      # !connect jdbc:hive2://big3.big:10001/default;principal=hive/big3.big@ADALTAS.COM 
      next null, 'TODO'

# Module Dependencies

    path = require 'path'
    parse_jdbc = require '../lib/parse_jdbc'
    mkcmd = require '../lib/mkcmd'



