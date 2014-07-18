---
title: 
layout: module
---

# HBase Master

    module.exports = []
    module.exports.push 'masson/bootstrap/'
    module.exports.push 'ryba/hadoop/hdfs'
    module.exports.push 'ryba/hbase/_'

    module.exports.push module.exports.configure = (ctx) ->
      require('../hadoop/hdfs').configure ctx
      require('./_').configure ctx

    module.exports.push name: 'HBase Master # Service', timeout: -1, callback: (ctx, next) ->
      ctx.service
        cmd: 'hbase-master'
      , (err, installed) ->
        next err, if installed then ctx.OK else ctx.PASS

    module.exports.push name: 'HBase Master # HDFS layout', timeout: -1, callback: (ctx, next) ->
      {hbase_user, hbase_site} = ctx.config.hdp
      ctx.waitForExecution mkcmd.hdfs(ctx, "hdfs dfs -test -d /apps"), code_skipped: 1, (err) ->
        return next err if err
        dirs = hbase_site['hbase.bulkload.staging.dir'].split '/'
        return next err "Invalid property \"hbase.bulkload.staging.dir\"" unless dirs.length > 2 and path.join('/', dirs[0], '/', dirs[1]) is '/apps'
        ctx.log "Create /apps/hbase"
        modified = false
        each(dirs.slice 2)
        .on 'item', (dir, index, next) ->
          dir = dirs.slice(0, 3 + index).join '/'
          cmd = """
          if hdfs dfs -ls #{dir} &>/dev/null; then exit 2; fi
          hdfs dfs -mkdir #{dir}
          hdfs dfs -chown #{hbase_user.name} #{dir}
          """
          cmd += "\nhdfs dfs -chmod 711 #{dir}"  if 3 + index is dirs.length
          ctx.execute
            cmd: mkcmd.hdfs ctx, cmd
            code_skipped: 2
          , (err, executed, stdout) ->
            modified = true if executed
            next err
        .on 'both', (err) ->
          next err, if modified then ctx.OK else ctx.PASS

## Zookeeper JAAS

JAAS configuration files for zookeeper to be deployed on the HBase Master, 
RegionServer, and HBase client host machines.

Environment file is enriched by "ryba/hbase/_ # HBase # Env".

    module.exports.push name: 'HBase Client # Zookeeper JAAS', timeout: -1, callback: (ctx, next) ->
      {jaas_server, hbase_conf_dir, hbase_user, hbase_group} = ctx.config.hdp
      ctx.write
        destination: "#{hbase_conf_dir}/hbase-master.jaas"
        content: jaas_server
        uid: hbase_user.name
        gid: hbase_group.name
        mode: 0o700
      , (err, written) ->
        return next err, if written then ctx.OK else ctx.PASS

    # module.exports.push name: 'HBase Master # Environment', timeout: -1, callback: (ctx, next) ->
    #   {jaas_client, hbase_conf_dir, hbase_user, hbase_group} = ctx.config.hdp
    #   ctx.fs.readFile "#{hbase_conf_dir}/hbase-env.sh", 'ascii', (err, content) ->
        
    #     console.log err, content

https://blogs.apache.org/hbase/entry/hbase_cell_security
https://hbase.apache.org/book/security.html

    module.exports.push name: 'HBase Master # Kerberos', callback: (ctx, next) ->
      {hadoop_group, hbase_user, hbase_site, realm} = ctx.config.hdp
      {kadmin_principal, kadmin_password, admin_server} = ctx.config.krb5.etc_krb5_conf.realms[realm]
      ctx.krb5_addprinc [
        principal: hbase_site['hbase.master.kerberos.principal'].replace '_HOST', ctx.config.host
        randkey: true
        keytab: hbase_site['hbase.master.keytab.file']
        uid: hbase_user.name
        gid: hadoop_group.name
        kadmin_principal: kadmin_principal
        kadmin_password: kadmin_password
        kadmin_server: admin_server
      # ,
      #   principal: hbase_site['hbase.thrift.kerberos.principal'].replace '_HOST', ctx.config.host
      #   randkey: true
      #   keytab: hbase_site['hbase.thrift.keytab.file']
      #   uid: hbase_user.name
      #   gid: hadoop_group.name
      #   kadmin_principal: kadmin_principal
      #   kadmin_password: kadmin_password
      #   kadmin_server: admin_server
      # ,
      #   principal: hbase_site['hbase.rest.kerberos.principal'].replace '_HOST', ctx.config.host
      #   randkey: true
      #   keytab: hbase_site['hbase.rest.keytab.file']
      #   uid: hbase_user.name
      #   gid: hadoop_group.name
      #   kadmin_principal: kadmin_principal
      #   kadmin_password: kadmin_password
      #   kadmin_server: admin_server
      ], (err, created) ->
        next err, if created then ctx.OK else ctx.PASS

## SPNEGO

Check if keytab file exists and if read permission is granted to the HBase user.

Note: The Namenode webapp located in "/usr/lib/hbase/hbase-webapps/master" is
using the hadoop conf directory to retrieve the SPNEGO keytab. The user "hbase"
is added membership to the group hadoop to gain read access.

    module.exports.push name: 'HBase Master # FIX SPNEGO', callback: (ctx, next) ->
      {hbase_site, hbase_user, hbase_group, hadoop_group} = ctx.config.hdp
      {hdfs_site} = ctx.config.hdp
      ctx.execute
        cmd: """
          if groups #{hbase_user.name} | grep #{hadoop_group.name}; then exit 2; fi
          usermod -G #{hadoop_group.name} #{hbase_user.name}
        """
        code_skipped: 2
      , (err, modified) ->
        return next err if err
        ctx.execute
          cmd: "su -l #{hbase_user.name} -c 'test -r /etc/security/keytabs/spnego.service.keytab'"
        , (err) ->
          next err, if modified then ctx.OK else ctx.PASS
      # ctx.copy [
      #   source: '/etc/security/keytabs/spnego.service.keytab'
      #   destination: hbase_site['hbase.thrift.keytab.file']
      #   uid: hbase_user.name
      #   gid: hbase_group.name
      #   mode: 0o660
      # ,
      #   source: '/etc/security/keytabs/spnego.service.keytab'
      #   destination: hbase_site['hbase.rest.authentication.kerberos.keytab']
      #   uid: hbase_user.name
      #   gid: hbase_group.name
      #   mode: 0o660
      
      # ], (err, copied) ->
      #   return next err, if copied then ctx.OK else ctx.PASS

## Metrics

Enable stats collection in Ganglia.

    module.exports.push name: 'HBase Master # Metrics', callback: (ctx, next) ->
      {hbase_conf_dir} = ctx.config.hdp
      collector = ctx.host_with_module 'ryba/hadoop/ganglia_collector'
      return next() unless collector
      ctx.upload
        source: "#{__dirname}/../hadoop/files/hbase/hadoop-metrics.properties.master-GANGLIA"
        destination: "#{hbase_conf_dir}/hadoop-metrics.properties"
        match: 'TODO-GANGLIA-SERVER'
        replace: collector
      , (err, uploaded) ->
        next err, if uploaded then ctx.OK else ctx.PASS

    module.exports.push 'ryba/hbase/master_start'

## Check

    module.exports.push 'ryba/hbase/master_check'

# Module dependencies

    each = require 'each'
    path = require 'path'
    lifecycle = require '../hadoop/lib/lifecycle'
    mkcmd = require '../hadoop/lib/mkcmd'

[HBASE-8409]: https://issues.apache.org/jira/browse/HBASE-8409
