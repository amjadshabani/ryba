---
title: 
layout: module
---

# Oozie Server Install

Oozie source code and examples are located in /usr/share/doc/oozie-4.0.0.2.0.6.0/

Note: to backup the oozie database in oozie, we must add the "hex-blob" option or 
we get an error while importing data. The mysqldump command does not escape all
charactere and the xml stored inside the database create syntax issues. Here's
an example:

```bash
mysqldump -uroot -ptest123 --hex-blob oozie > /data/1/oozie.sql
```

    module.exports = []
    module.exports.push 'masson/bootstrap/'
    module.exports.push 'masson/core/iptables'
    module.exports.push 'masson/commons/mysql_client'
    module.exports.push 'ryba/hadoop/core'
    module.exports.push 'ryba/hadoop/hdfs' # SPNEGO need access to the principal HTTP/$HOST@$REALM's keytab
    module.exports.push require('./server').configure

## Users & Groups

By default, the "oozie" package create the following entries:

```bash
cat /etc/passwd | grep oozie
oozie:x:493:493:Oozie User:/var/lib/oozie:/bin/bash
cat /etc/group | grep oozie
oozie:x:493:
```

    module.exports.push name: 'Oozie Server # Users & Groups', callback: (ctx, next) ->
      {oozie_group, oozie_user} = ctx.config.ryba
      ctx.group oozie_group, (err, gmodified) ->
        return next err if err
        ctx.user oozie_user, (err, umodified) ->
          next err, gmodified or umodified

## IPTables

| Service | Port  | Proto | Info              |
|---------|-------|-------|-------------------|
| oozie   | 11000 | http  | Oozie HTTP server |

IPTables rules are only inserted if the parameter "iptables.action" is set to 
"start" (default value).

    module.exports.push name: 'Oozie Server # IPTables', callback: (ctx, next) ->
      {oozie_site} = ctx.config.ryba
      port = url.parse(oozie_site['oozie.base.url']).port
      ctx.iptables
        rules: [
          { chain: 'INPUT', jump: 'ACCEPT', dport: port, protocol: 'tcp', state: 'NEW', comment: "Oozie HTTP Server" }
        ]
        if: ctx.config.iptables.action is 'start'
      , next

    module.exports.push name: 'Oozie Server # Install', timeout: -1, callback: (ctx, next) ->
      ctx.service [
        name: 'oozie' # Also install oozie-client and bigtop-tomcat
      ,
        name: 'unzip' # Required by the "prepare-war" command
      ,
        name: 'extjs-2.2-1'
      ], (err, serviced) ->
        ctx.config.ryba.force_war = true if serviced
        next err, serviced

    module.exports.push name: 'Oozie Server # Environment', callback: (ctx, next) ->
      {java_home} = ctx.config.java
      {oozie_user, hadoop_group, oozie_conf_dir, oozie_log_dir, oozie_pid_dir, oozie_data} = ctx.config.ryba
      ctx.write
        source: "#{__dirname}/../resources/oozie/oozie-env.sh"
        destination: "#{oozie_conf_dir}/oozie-env.sh"
        local_source: true
        write: [
          match: /^export JAVA_HOME=.*$/mg
          replace: "export JAVA_HOME=#{java_home}"
          append: true
        ,
          match: /^export JRE_HOME=.*$/mg
          replace: "export JRE_HOME=${JAVA_HOME}" # Not in HDP 2.0.6 but mentioned in [HDP 2.1 doc](http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.1-latest/bk_installing_manually_book/content/rpm-chap8-3.html)
          append: true
        ,
          match: /^export OOZIE_CONFIG=.*$/mg
          replace: "export OOZIE_CONFIG=${OOZIE_CONFIG:-/etc/oozie/conf}"
          append: true
        ,
          match: /^export CATALINA_BASE=.*$/mg
          replace: "export CATALINA_BASE=${CATALINA_BASE:-/var/lib/oozie/tomcat-deployment}"
          append: true
        ,
          match: /^export CATALINA_TMPDIR=.*$/mg
          replace: "export CATALINA_TMPDIR=${CATALINA_TMPDIR:-/var/tmp/oozie}"
          append: true
        ,
          match: /^export OOZIE_CATALINA_HOME=.*$/mg
          replace: "export OOZIE_CATALINA_HOME=/usr/lib/bigtop-tomcat"
          append: true
        ,
          match: /^export OOZIE_DATA=.*$/mg
          replace: "export OOZIE_DATA=#{oozie_data}"
          append: true
        ]
        uid: oozie_user.name
        gid: hadoop_group.name
        mode: 0o0755
      , next

    module.exports.push name: 'Oozie Server # Directories', callback: (ctx, next) ->
      {oozie_user, oozie_group, oozie_data, oozie_conf_dir, oozie_log_dir, oozie_pid_dir, oozie_tmp_dir} = ctx.config.ryba
      oozie_user = oozie_user.name
      oozie_group = oozie_group.name
      ctx.mkdir [
        destination: oozie_data
        uid: oozie_user
        gid: oozie_group
        mode: 0o0755
      ,
        destination: oozie_log_dir
        uid: oozie_user
        gid: oozie_group
        mode: 0o0755
      ,
        destination: oozie_pid_dir
        uid: oozie_user
        gid: oozie_group
        mode: 0o0755
      ,
        destination: oozie_tmp_dir
        uid: oozie_user
        gid: oozie_group
        mode: 0o0755
      ,
        destination: "#{oozie_conf_dir}/action-conf"
        uid: oozie_user
        gid: oozie_group
        mode: 0o0755
      ], (err, copied) ->
        return next err if err
        # Waiting for recursivity in ctx.mkdir
        ctx.execute
          cmd: """
          chown -R #{oozie_user}:#{oozie_group} /usr/lib/oozie
          chown -R #{oozie_user}:#{oozie_group} #{oozie_data}
          chown -R #{oozie_user}:#{oozie_group} #{oozie_conf_dir}/..
          chmod -R 755 #{oozie_conf_dir}/..
          """
        , (err, executed) ->
          next err, copied

    module.exports.push name: 'Oozie Server # ExtJS', callback: (ctx, next) ->
      ctx.copy
        source: '/usr/share/HDP-oozie/ext-2.2.zip'
        destination: '/usr/lib/oozie/libext/'
      , (err, copied) ->
        ctx.config.ryba.force_war = true if copied
        return next err, copied

    module.exports.push name: 'Oozie Server # LZO', callback: (ctx, next) ->
      ctx.execute
        cmd: 'ls /usr/lib/hadoop/lib/hadoop-lzo-*.jar'
      , (err, _, stdout) ->
        return next err if err
        lzo_jar = stdout.trim()
        ctx.execute
          cmd: """
          # Remove any previously installed version
          rm /usr/lib/oozie/libext/hadoop-lzo-*.jar
          # Copy lzo
          cp #{lzo_jar} /usr/lib/oozie/libext/
          """
          not_if_exists: "/usr/lib/oozie/libext/#{path.basename lzo_jar}"
        , next

    module.exports.push name: 'Oozie Server # Mysql Driver', callback: (ctx, next) ->
      ctx.link
        source: '/usr/share/java/mysql-connector-java.jar'
        destination: '/usr/lib/oozie/libext/mysql-connector-java.jar'
      , (err, linked) ->
        ctx.config.ryba.force_war = true if linked
        return next err, linked

    module.exports.push name: 'Oozie Server # Configuration', callback: (ctx, next) ->
      { hadoop_conf_dir, yarn_site, oozie_group, oozie_user, 
        oozie_site, oozie_conf_dir, oozie_hadoop_config } = ctx.config.ryba
      modified = false
      do_oozie_site = ->
        ctx.log 'Configure oozie-site.xml'
        ctx.hconfigure
          destination: "#{oozie_conf_dir}/oozie-site.xml"
          default: "#{__dirname}/../resources/oozie/oozie-site.xml"
          local_default: true
          properties: oozie_site
          uid: oozie_user.name
          gid: oozie_group.name
          mode: 0o0755
          merge: true
          backup: true
        , (err, configured) ->
          return next err if err
          modified = true if configured
          do_hadoop_config()
      do_hadoop_config = ->
        ctx.log 'Configure hadoop-config.xml'
        ctx.hconfigure
          destination: "#{oozie_conf_dir}/hadoop-conf/core-site.xml"
          local_default: true
          properties: oozie_hadoop_config
          uid: oozie_user.name
          gid: oozie_group.name
          mode: 0o0755
          backup: true
        , (err, configured) ->
          return next err if err
          modified = true if configured
          do_end()
      do_end = ->
        next null, modified
      do_oozie_site()

    module.exports.push name: 'Oozie Server # War', callback: (ctx, next) ->
      {oozie_user} = ctx.config.ryba
      # The script `ooziedb.sh` must be done as the oozie Unix user, otherwise 
      # Oozie may fail to start or work properly because of incorrect file permissions.
      # There is already a "oozie.war" file inside /var/lib/oozie/oozie-server/webapps/.
      # The "prepare-war" command generate the file "/var/lib/oozie/oozie-server/webapps/oozie.war".
      # The directory being servered by the web server is "/usr/lib/oozie/webapps/oozie".
      ctx.execute
        cmd: "su -l #{oozie_user.name} -c '/usr/lib/oozie/bin/oozie-setup.sh prepare-war'"
        not_if: not ctx.config.ryba.force_war
      , next

    module.exports.push name: 'Oozie Server # Kerberos', callback: (ctx, next) ->
      {oozie_user, oozie_group, oozie_site, realm} = ctx.config.ryba
      {kadmin_principal, kadmin_password, admin_server} = ctx.config.krb5.etc_krb5_conf.realms[realm]
      ctx.krb5_addprinc
        principal: oozie_site['oozie.service.HadoopAccessorService.kerberos.principal'] #.replace '_HOST', ctx.config.host
        randkey: true
        keytab: oozie_site['oozie.service.HadoopAccessorService.keytab.file']
        uid: oozie_user.name
        gid: oozie_group.name
        kadmin_principal: kadmin_principal
        kadmin_password: kadmin_password
        kadmin_server: admin_server
      , next

    module.exports.push name: 'Oozie Server # SPNEGO', callback: (ctx, next) ->
      {oozie_site, oozie_user, oozie_group} = ctx.config.ryba
      ctx.copy
        source: '/etc/security/keytabs/spnego.service.keytab'
        destination: "#{oozie_site['oozie.authentication.kerberos.keytab']}"
        uid: oozie_user.name
        gid: oozie_group.name
        mode: 0o0600
      , next

    module.exports.push name: 'Oozie Server # MySQL', callback: (ctx, next) ->
      {db_admin, oozie_db_host, oozie_site} = ctx.config.ryba
      username = oozie_site['oozie.service.JPAService.jdbc.username']
      password = oozie_site['oozie.service.JPAService.jdbc.password']
      {engine, db} = parse_jdbc oozie_site['oozie.service.JPAService.jdbc.url']
      engines = 
        mysql: ->
          escape = (text) -> text.replace(/[\\"]/g, "\\$&")
          cmd = "#{db_admin.path} -u#{db_admin.username} -p#{db_admin.password} -h#{db_admin.host} -P#{db_admin.port} -e "
          ctx.execute
            cmd: """
            if #{cmd} "use #{db}"; then exit 2; fi
            #{cmd} "
            create database #{db};
            grant all privileges on #{db}.* to '#{username}'@'localhost' identified by '#{password}';
            grant all privileges on #{db}.* to '#{username}'@'%' identified by '#{password}';
            flush privileges;
            "
            """
            code_skipped: 2
          , next
      return next new Error 'Database engine not supported' unless engines[engine]
      engines[engine]()

    module.exports.push name: 'Oozie Server # Database', callback: (ctx, next) ->
      {oozie_user} = ctx.config.ryba
      ctx.execute
        cmd: """
        su -l #{oozie_user.name} -c '/usr/lib/oozie/bin/ooziedb.sh create -sqlfile oozie.sql -run Validate DB Connection'
        """
      , (err, executed, stdout, stderr) ->
        err = null if err and /DB schema exists/.test stderr
        next err, executed

    module.exports.push name: 'Oozie Server # Share lib', callback: (ctx, next) ->
      {oozie_user, oozie_group} = ctx.config.ryba
      oozie_user = oozie_user.name
      oozie_group = oozie_group.name
      ctx.execute 
        cmd: mkcmd.hdfs ctx, """
        if hdfs dfs -ls /user/#{oozie_user}/share &>/dev/null; then exit 2; fi
        mkdir /tmp/ooziesharelib
        cd /tmp/ooziesharelib
        tar xzf /usr/lib/oozie/oozie-sharelib.tar.gz
        hdfs dfs -mkdir /user/#{oozie_user}
        hdfs dfs -put share /user/#{oozie_user}
        hdfs dfs -chown #{oozie_user}:#{oozie_group} /user/#{oozie_user}
        hdfs dfs -chmod -R 755 /user/#{oozie_user}
        rm -rf /tmp/ooziesharelib
        """
        code_skipped: 2
      , next

    module.exports.push 'ryba/oozie/server_start'

    module.exports.push 'ryba/oozie/client'

## Module Dependencies

    url = require 'url'
    path = require 'path'
    lifecycle = require '../lib/lifecycle'
    mkcmd = require '../lib/mkcmd'
    parse_jdbc = require '../lib/parse_jdbc'
  





