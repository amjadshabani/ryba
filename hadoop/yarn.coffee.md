---
title: 
layout: module
---

# YARN

    url = require 'url'
    misc = require 'mecano/lib/misc'
    mkcmd = require './lib/mkcmd'
    module.exports = []
    module.exports.push 'masson/bootstrap/'
    module.exports.push 'phyla/hadoop/core'

    module.exports.push module.exports.configure = (ctx) ->
      return if ctx.yarn_configured
      ctx.yarn_configured = true
      require('./hdfs').configure ctx
      {static_host, realm} = ctx.config.hdp
      # Grab the host(s) for each roles
      resourcemanager = ctx.host_with_module 'phyla/hadoop/yarn_rm'
      ctx.log "Resource manager: #{resourcemanager}"
      jobhistoryserver = ctx.host_with_module 'phyla/hadoop/mapred_jhs'
      ctx.log "Job History Server: #{jobhistoryserver}"
      ctx.config.hdp.yarn_log_dir ?= '/var/log/hadoop-yarn'         # /etc/hadoop/conf/yarn-env.sh#20
      ctx.config.hdp.yarn_pid_dir ?= '/var/run/hadoop-yarn'         # /etc/hadoop/conf/yarn-env.sh#21
      # Define Users and Groups
      ctx.config.hdp.yarn_user ?= 'yarn'
      ctx.config.hdp.yarn_group ?= 'yarn'
      # Configure yarn
      # Comma separated list of paths. Use the list of directories from $YARN_LOCAL_DIR, eg: /grid/hadoop/hdfs/yarn/local,/grid1/hadoop/hdfs/yarn/local.
      throw new Error 'Required property: hdp.yarn[yarn.nodemanager.local-dirs]' unless ctx.config.hdp.yarn['yarn.nodemanager.local-dirs']
      # Use the list of directories from $YARN_LOCAL_LOG_DIR, eg: /grid/hadoop/yarn/logs /grid1/hadoop/yarn/logs /grid2/hadoop/yarn/logs
      throw new Error 'Required property: hdp.yarn[yarn.nodemanager.log-dirs]' unless ctx.config.hdp.yarn['yarn.nodemanager.log-dirs']
      ctx.config.hdp.yarn['yarn.resourcemanager.resource-tracker.address'] ?= "#{resourcemanager}:8025" # Enter your ResourceManager hostname.
      ctx.config.hdp.yarn['yarn.resourcemanager.scheduler.address'] ?= "#{resourcemanager}:8030" # Enter your ResourceManager hostname.
      ctx.config.hdp.yarn['yarn.resourcemanager.address'] ?= "#{resourcemanager}:8050" # Enter your ResourceManager hostname.
      ctx.config.hdp.yarn['yarn.resourcemanager.admin.address'] ?= "#{resourcemanager}:8041" # Enter your ResourceManager hostname.
      ctx.config.hdp.yarn['yarn.nodemanager.remote-app-log-dir'] ?= "/logs"
      ctx.config.hdp.yarn['yarn.log.server.url'] ?= "http://#{jobhistoryserver}:19888/jobhistory/logs/" # URL for job history server
      ctx.config.hdp.yarn['yarn.resourcemanager.webapp.address'] ?= "#{resourcemanager}:8088" # URL for job history server
      ctx.config.hdp.yarn['yarn.nodemanager.container-executor.class'] ?= 'org.apache.hadoop.yarn.server.nodemanager.LinuxContainerExecutor'
      ctx.config.hdp.yarn['yarn.nodemanager.linux-container-executor.group'] ?= 'yarn'
      # Required by yarn client
      ctx.config.hdp.yarn['yarn.resourcemanager.principal'] ?= "rm/#{static_host}@#{realm}"
      # Configurations for History Server (Needs to be moved elsewhere):
      ctx.config.hdp.yarn['yarn.log-aggregation.retain-seconds'] ?= '-1' #  How long to keep aggregation logs before deleting them. -1 disables. Be careful, set this too small and you will spam the name node.
      ctx.config.hdp.yarn['yarn.log-aggregation.retain-check-interval-seconds'] ?= '-1' # Time between checks for aggregated log retention. If set to 0 or a negative value then the value is computed as one-tenth of the aggregated log retention time. Be careful, set this too small and you will spam the name node.
      # [Container Executor](http://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/ClusterSetup.html#Configuration_in_Secure_Mode)
      ctx.config.hdp.container_executor ?= {}
      ctx.config.hdp.container_executor['yarn.nodemanager.local-dirs'] ?= ctx.config.hdp.yarn['yarn.nodemanager.local-dirs']
      ctx.config.hdp.container_executor['yarn.nodemanager.linux-container-executor.group'] ?= ctx.config.hdp.yarn['yarn.nodemanager.linux-container-executor.group']
      ctx.config.hdp.container_executor['yarn.nodemanager.log-dirs'] = ctx.config.hdp.yarn['yarn.nodemanager.log-dirs']
      ctx.config.hdp.container_executor['banned.users'] ?= 'hfds,yarn,mapred,bin'
      ctx.config.hdp.container_executor['min.user.id'] ?= '0'

http://docs.hortonworks.com/HDPDocuments/HDP1/HDP-1.2.3.1/bk_installing_manually_book/content/rpm-chap1-9.html
http://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/ClusterSetup.html#Running_Hadoop_in_Secure_Mode

    module.exports.push name: 'HDP YARN # Users & Groups', callback: (ctx, next) ->
      return next() unless ctx.config.hdp.resourcemanager or ctx.config.hdp.nodemanager
      {hadoop_group} = ctx.config.hdp
      ctx.execute
        cmd: "useradd yarn -r -M -g #{hadoop_group} -s /bin/bash -c \"Used by Hadoop YARN service\""
        code: 0
        code_skipped: 9
      , (err, executed) ->
        next err, if executed then ctx.OK else ctx.PASS

    module.exports.push name: 'HDP YARN # Install Common', timeout: -1, callback: (ctx, next) ->
      ctx.service [
        name: 'hadoop'
      ,
        name: 'hadoop-yarn'
      ,
        name: 'hadoop-client'
      ], (err, serviced) ->
        next err, if serviced then ctx.OK else ctx.PASS

    module.exports.push name: 'HDP YARN # Directories', timeout: -1, callback: (ctx, next) ->
      { yarn_user,
        yarn, yarn_log_dir, yarn_pid_dir,
        hadoop_group } = ctx.config.hdp
      modified = false
      do_yarn_log_dirs = -> # not the tranditionnal log dir
        ctx.log "Create yarn dirs: #{yarn['yarn.nodemanager.log-dirs'].join ','}"
        ctx.mkdir
          destination: yarn['yarn.nodemanager.log-dirs']
          uid: yarn_user
          gid: hadoop_group
          mode: 0o0755
        , (err, created) ->
          return next err if err
          modified = true if created
          do_yarn_local_log()
      do_yarn_local_log = ->
        ctx.log "Create yarn dirs: #{yarn['yarn.nodemanager.local-dirs'].join ','}"
        ctx.mkdir
          destination: yarn['yarn.nodemanager.local-dirs']
          uid: yarn_user
          gid: hadoop_group
          mode: 0o0755
        , (err, created) ->
          return next err if err
          modified = true if created
          do_log()
      do_log = ->
        ctx.log "Create hdfs and mapred log: #{yarn_log_dir}"
        ctx.mkdir
          destination: "#{yarn_log_dir}/#{yarn_user}"
          uid: yarn_user
          gid: hadoop_group
          mode: 0o0755
        , (err, created) ->
          return next err if err
          modified = true if created
          do_pid()
      do_pid = ->
        ctx.log "Create pid: #{yarn_pid_dir}"
        ctx.mkdir
          destination: "#{yarn_pid_dir}/#{yarn_user}"
          uid: yarn_user
          gid: hadoop_group
          mode: 0o0755
        , (err, created) ->
          return next err if err
          modified = true if created
          do_end()
      do_end = ->
        next null, if modified then ctx.OK else ctx.PASS
      do_yarn_log_dirs()

    module.exports.push name: 'HDP YARN # Yarn OPTS', callback: (ctx, next) ->
      {yarn_user, hadoop_group, hadoop_conf_dir} = ctx.config.hdp
      yarn_opts = ""
      for k, v of ctx.config.hdp.yarn_opts
        yarn_opts += "-D#{k}=#{v} "
      yarn_opts = "YARN_OPTS=\"$YARN_OPTS #{yarn_opts}\" # Phyla"
      ctx.config.hdp.yarn_opts = yarn_opts
      ctx.render
        source: "#{__dirname}/files/core_hadoop/yarn-env.sh"
        destination: "#{hadoop_conf_dir}/yarn-env.sh"
        local_source: true
        write: [
          match: /^.*Phyla$/mg
          replace: yarn_opts
          append: 'yarn.policy.file'
        ]
        uid: yarn_user
        gid: hadoop_group
        mode: 0o0755
      , (err, rendered) ->
        next err, if rendered then ctx.OK else ctx.PASS

    module.exports.push name: 'HDP YARN # Container Executor', callback: (ctx, next) ->
      modified = false
      {yarn_user, yarn_group, container_executor, hadoop_conf_dir} = ctx.config.hdp
      container_executor = misc.merge {}, container_executor
      container_executor['yarn.nodemanager.local-dirs'] = container_executor['yarn.nodemanager.local-dirs'].join ','
      container_executor['yarn.nodemanager.log-dirs'] = container_executor['yarn.nodemanager.log-dirs'].join ','
      do_stat = ->
        ce = '/usr/lib/hadoop-yarn/bin/container-executor';
        ctx.log "change ownerships and permissions to '#{ce}'"
        ctx.chown
          destination: ce
          uid: 'root'
          gid: yarn_group
        , (err, chowned) ->
          return next err if err
          modified = true if chowned
          ctx.chmod
            destination: ce
            mode: 0o6050
          , (err, chmoded) ->
            return next err if err
            modified = true if chmoded
            do_conf()
      do_conf = ->
        ctx.log "Write to '#{hadoop_conf_dir}/container-executor.cfg' as ini"
        ctx.ini
          destination: "#{hadoop_conf_dir}/container-executor.cfg"
          content: container_executor
          uid: 'root'
          gid: yarn_group
          mode: 0o0640
          separator: '='
          backup: true
        , (err, inied) ->
          modified = true if inied
          next err, if modified then ctx.OK else ctx.PASS
      do_stat()

    module.exports.push name: 'HDP YARN # Configuration', callback: (ctx, next) ->
      { yarn, hadoop_conf_dir, capacity_scheduler } = ctx.config.hdp
      modified = false
      do_yarn = ->
        ctx.log 'Configure yarn-site.xml'
        config = {}
        for k,v of yarn then config[k] = v 
        config['yarn.nodemanager.local-dirs'] = config['yarn.nodemanager.local-dirs'].join ',' if Array.isArray yarn['yarn.nodemanager.local-dirs']
        config['yarn.nodemanager.log-dirs'] = config['yarn.nodemanager.log-dirs'].join ',' if Array.isArray yarn['yarn.nodemanager.log-dirs']
        ctx.hconfigure
          destination: "#{hadoop_conf_dir}/yarn-site.xml"
          default: "#{__dirname}/files/core_hadoop/yarn-site.xml"
          local_default: true
          properties: config
          merge: true
        , (err, configured) ->
          return next err if err
          modified = true if configured
          do_capacity_scheduler()
      do_capacity_scheduler = ->
        ctx.log 'Configure capacity-scheduler.xml'
        ctx.hconfigure
          destination: "#{hadoop_conf_dir}/capacity-scheduler.xml"
          default: "#{__dirname}/files/core_hadoop/capacity-scheduler.xml"
          local_default: true
          properties: capacity_scheduler
          merge: true
        , (err, configured) ->
          return next err if err
          modified = true if configured
          do_end()
      do_end = ->
        next null, if modified then ctx.OK else ctx.PASS
      do_yarn()

HDP YARN # Tuning

yarn.nodemanager.vmem-pmem-ratio property: Is defines ratio of virtual memory to available pysical memory, Here is 2.1 means virtual memory will be double the size of physical memory.

yarn.app.mapreduce.am.command-opts: In yarn ApplicationMaster(AM) is responsible for securing necessary resources. So this property defines how much memory required to run AM itself. Don't confuse this with nodemanager, where job will be executed.

yarn.app.mapreduce.am.resource.mb: This property specify criteria to select resource for particular job. Here is given 1536 Means any nodemanager which has equal or more memory available will get selected for executing job.

Ressources:
http://stackoverflow.com/questions/18692631/difference-between-3-memory-parameters-in-hadoop-2

    module.exports.push name: 'HDP YARN # Tuning', callback: (ctx, next) ->
      # yarn.nodemanager.resource.memory-mb
      # yarn.nodemanager.vmem-pmem-ratio
      # yarn.scheduler.maximum-allocation-mb
      # yarn.scheduler.minimum-allocation-mb
      # yarn.nodemanager.log.retain-seconds (cherif mettre la valeur à 10800 au lie de 604800)
      # yarn.log-aggregation.retain-seconds (chefrif)
      next null, "TODO"

    module.exports.push name: 'HDP YARN # Keytabs Directory', timeout: -1, callback: (ctx, next) ->
      ctx.mkdir
        destination: '/etc/security/keytabs'
        uid: 'root'
        gid: 'hadoop'
        mode: 0o750
      , (err, created) ->
        next null, if created then ctx.OK else ctx.PASS

    module.exports.push name: 'HDP YARN # Configure Kerberos', callback: (ctx, next) ->
      {hadoop_conf_dir, static_host, realm} = ctx.config.hdp
      yarn = {}
      # Todo: might need to configure WebAppProxy but I understood that it is run as part of rm if not configured separately
      # yarn.web-proxy.address    WebAppProxy                                   host:port for proxy to AM web apps. host:port if this is the same as yarn.resourcemanager.webapp.address or it is not defined then the ResourceManager will run the proxy otherwise a standalone proxy server will need to be launched.
      # yarn.web-proxy.keytab     /etc/security/keytabs/web-app.service.keytab  Kerberos keytab file for the WebAppProxy.
      # yarn.web-proxy.principal  wap/_HOST@REALM.TLD                           Kerberos principal name for the WebAppProxy.
      # Todo: need to deploy "container-executor.cfg"
      # see http://hadoop.apache.org/docs/r2.1.0-beta/hadoop-project-dist/hadoop-common/ClusterSetup.html#Running_Hadoop_in_Secure_Mode
      # Configurations the ResourceManager
      yarn['yarn.resourcemanager.keytab'] ?= '/etc/security/keytabs/rm.service.keytab'
      # Configurations for NodeManager:
      yarn['yarn.nodemanager.keytab'] ?= '/etc/security/keytabs/nm.service.keytab'
      yarn['yarn.nodemanager.principal'] ?= "nm/#{static_host}@#{realm}"
      ctx.hconfigure
        destination: "#{hadoop_conf_dir}/yarn-site.xml"
        properties: yarn
        merge: true
      , (err, configured) ->
        next err, if configured then ctx.OK else ctx.PASS

Layout is inspired by [Hadoop recommandation](http://hadoop.apache.org/docs/r2.1.0-beta/hadoop-project-dist/hadoop-common/ClusterSetup.html)

    module.exports.push name: 'HDP YARN # HDFS layout', callback: (ctx, next) ->
      {hadoop_group, hdfs_user, yarn, yarn_user} = ctx.config.hdp
      ok = false
      do_remote_app_log_dir = ->
        # Default value for "yarn.nodemanager.remote-app-log-dir" is "/tmp/logs"
        remote_app_log_dir = yarn['yarn.nodemanager.remote-app-log-dir']
        ctx.log "Create #{remote_app_log_dir}"
        ctx.execute
          cmd: mkcmd.hdfs ctx, """
          if hdfs dfs -test -d #{remote_app_log_dir}; then exit 1; fi
          hdfs dfs -mkdir -p #{remote_app_log_dir}
          hdfs dfs -chown #{yarn_user}:#{hadoop_group} #{remote_app_log_dir}
          hdfs dfs -chmod 777 #{remote_app_log_dir}
          """
          code_skipped: 1
        , (err, executed, stdout) ->
          return next err if err
          ok = true if executed
          do_end()
      do_end = ->
        next null, if ok then ctx.OK else ctx.PASS
      do_remote_app_log_dir()










