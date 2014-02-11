
###
http://hadoop.apache.org/docs/r2.1.0-beta/hadoop-project-dist/hadoop-common/ClusterSetup.html
###
lifecyle = module.exports =
  jn_start: (ctx, callback) ->
    {hdfs_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hdfs -c "/usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf --script hdfs start journalnode"
      cmd: "su -l #{hdfs_user} -c \"/usr/lib/hadoop/sbin/hadoop-daemon.sh --config #{hadoop_conf_dir} --script hdfs start journalnode\""
      code_skipped: 1
    , (err, started) ->
      callback err, started
  jn_stop: (ctx, callback) ->
    {hdfs_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hdfs -c "/usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf --script hdfs start journalnode"
      cmd: "su -l #{hdfs_user} -c \"/usr/lib/hadoop/sbin/hadoop-daemon.sh --config #{hadoop_conf_dir} --script hdfs stop journalnode\""
      code_skipped: 1
    , (err, started) ->
      callback err, started
  nn_start: (ctx, callback) ->
    {hdfs_user, hadoop_conf_dir} = ctx.config.hdp
    # Version 1:
    # # su -l hdfs -c "/usr/lib/hadoop/bin/hadoop-daemon.sh --config /etc/hadoop/conf start namenode"
    # cmd: "su -l #{hdfs_user} -c \"/usr/lib/hadoop/bin/hadoop-daemon.sh --config #{hadoop_conf_dir} start namenode\""
    ctx.execute
      # su -l hdfs -c "/usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf --script hdfs start namenode"
      cmd: "su -l #{hdfs_user} -c \"/usr/lib/hadoop/sbin/hadoop-daemon.sh --config #{hadoop_conf_dir} --script hdfs start namenode\""
      code_skipped: 1
    , (err, started) ->
      callback err, started
  nn_running: (ctx, callback) ->
    {hdfs_pid_dir} = ctx.config.hdp
    ctx.execute
      cmd: "kill -0 `cat #{hdfs_pid_dir}/hadoop-hdfs-namenode.pid`"
      code_skipped: 1
    , callback
  nn_stop: (ctx, callback) ->
    {hdfs_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hdfs -c "/usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf --script hdfs stop namenode"
      cmd: "su -l #{hdfs_user} -c \"/usr/lib/hadoop/sbin/hadoop-daemon.sh --config #{hadoop_conf_dir} --script hdfs stop namenode\""
      code_skipped: 1
    , (err, stoped) ->
      callback err, stoped
  snn_start: (ctx, callback) ->
    {hdfs_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hdfs -c "/usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf start secondarynamenode"
      cmd: "su -l #{hdfs_user} -c \"/usr/lib/hadoop/sbin/hadoop-daemon.sh --config #{hadoop_conf_dir} start secondarynamenode\""
      code_skipped: 1
    , (err, started) ->
      callback err, started
  snn_stop: (ctx, callback) ->
    {hdfs_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hdfs -c "/usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf stop secondarynamenode"
      cmd: "su -l #{hdfs_user} -c \"/usr/lib/hadoop/sbin/hadoop-daemon.sh --config #{hadoop_conf_dir} stop secondarynamenode\""
      code_skipped: 1
    , (err, stoped) ->
      callback err, stoped
  dn_start: (ctx, callback) ->
    {hdfs_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # HADOOP_SECURE_DN_USER=hdfs /usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf --script hdfs start datanode
      cmd: "HADOOP_SECURE_DN_USER=hdfs /usr/lib/hadoop/sbin/hadoop-daemon.sh --config #{hadoop_conf_dir} --script hdfs start datanode"
      code_skipped: 1
    , (err, started) ->
      callback err, if started then ctx.OK else ctx.PASS
  dn_stop: (ctx, callback) ->
    {hdfs_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hdfs -c "/usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf stop datanode"
      # cmd: "su -l #{hdfs_user} -c \"/usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf stop datanode\""
      # /usr/lib/hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf stop datanode
      cmd: "/usr/lib/hadoop/sbin/hadoop-daemon.sh --config #{hadoop_conf_dir} stop datanode"
      code_skipped: 1
    , (err, stoped) ->
      callback err, if stoped then ctx.OK else ctx.PASS
  rm_start: (ctx, callback) ->
    {yarn_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l yarn -c "export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop-yarn/sbin/yarn-daemon.sh --config /etc/hadoop/conf start resourcemanager"
      cmd: "su -l #{yarn_user} -c \"export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop-yarn/sbin/yarn-daemon.sh --config #{hadoop_conf_dir} start resourcemanager\""
      code_skipped: 1
    , (err, started) ->
      callback err, started
  rm_stop: (ctx, callback) ->
    {yarn_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l yarn -c "export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop-yarn/sbin/yarn-daemon.sh --config /etc/hadoop/conf stop resourcemanager"
      cmd: "su -l #{yarn_user} -c \"export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop-yarn/sbin/yarn-daemon.sh --config #{hadoop_conf_dir} stop resourcemanager\""
      code_skipped: 1
    , (err, stoped) ->
      callback err, stoped
  nm_start: (ctx, callback) ->
    {yarn_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l yarn -c "export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop-yarn/sbin/yarn-daemon.sh --config /etc/hadoop/conf start nodemanager"
      cmd: "su -l #{yarn_user} -c \"export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop-yarn/sbin/yarn-daemon.sh --config #{hadoop_conf_dir} start nodemanager\""
      code_skipped: 1
    , (err, started) ->
      callback err, started
  nm_stop: (ctx, callback) ->
    {yarn_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l yarn -c "export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop-yarn/sbin/yarn-daemon.sh --config /etc/hadoop/conf stop nodemanager"
      cmd: "su -l #{yarn_user} -c \"export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec && /usr/lib/hadoop-yarn/sbin/yarn-daemon.sh --config #{hadoop_conf_dir} stop nodemanager\""
      code_skipped: 1
    , (err, stoped) ->
      callback err, stoped
  jhs_start: (ctx, callback) ->
    {mapred_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l mapred -c "export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec/ && /usr/lib/hadoop-mapreduce/sbin/mr-jobhistory-daemon.sh --config /etc/hadoop/conf start historyserver"
      cmd: "su -l #{mapred_user} -c \"export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec/ && /usr/lib/hadoop-mapreduce/sbin/mr-jobhistory-daemon.sh --config #{hadoop_conf_dir} start historyserver\""
      code_skipped: 1
    , (err, started) ->
      callback err, started
  jhs_stop: (ctx, callback) ->
    {mapred_user, hadoop_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l mapred -c "export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec/ && /usr/lib/hadoop-mapreduce/sbin/mr-jobhistory-daemon.sh --config /etc/hadoop/conf stop historyserver"
      cmd: "su -l #{mapred_user} -c \"export HADOOP_LIBEXEC_DIR=/usr/lib/hadoop/libexec/ && /usr/lib/hadoop-mapreduce/sbin/mr-jobhistory-daemon.sh --config #{hadoop_conf_dir} stop historyserver\""
      code_skipped: 1
    , (err, started) ->
      callback err, started
  hive_metastore_status: (ctx, callback) ->
    # {hive_metastore_pid} = ctx.config.hdp
    lifecyle.is_pidfile_running ctx, "/var/run/hive/metastore.pid", (err, running) ->
      callback err, running
  hive_metastore_start: (ctx, callback) ->
    {hive_user, hive_log_dir, hive_pid_dir, hive_metastore_host, hive_metastore_port, hive_metastore_timeout} = ctx.config.hdp
    lifecyle.hive_metastore_status ctx, (err, running) ->
      return callback err, false if err or running
      ctx.execute
        # su -l hive -c 'nohup hive --service metastore >/var/log/hive/hive.out 2>/var/log/hive/hive.log & echo $! >/var/run/hive/metastore.pid'
        # su -l hive -c 'hive --service metastore'
        cmd: "su -l #{hive_user} -c 'nohup hive --service metastore >#{hive_log_dir}/hive.out 2>#{hive_log_dir}/hive.log & echo $! > /var/run/hive/metastore.pid'"
        code_skipped: 1
      , (err, started) ->
        return callback err if err
        ctx.waitForConnection hive_metastore_host, hive_metastore_port, hive_metastore_timeout, (err) ->
          callback err, started
  hive_metastore_stop: (ctx, callback) ->
    {hive_user, hive_pid_dir} = ctx.config.hdp
    lifecyle.hive_metastore_status ctx, (err, running) ->
      return callback err, false if err or not running
      ctx.execute
        # su -l hive -c "kill `cat /var/run/hive/metastore.pid`"
        cmd: "su -l #{hive_user} -c \"kill `cat #{hive_pid_dir}/metastore.pid`\""
        code_skipped: 1
      , (err, started) ->
        callback err, started
  hive_metastore_restart: (ctx, callback) ->
    lifecyle.hive_metastore_stop ctx, (err) ->
      return callback err if err
      lifecyle.hive_metastore_start ctx, callback
  hive_server2_status: (ctx, callback) ->
    # {hive_server2_pid} = ctx.config.hdp
    lifecyle.is_pidfile_running ctx, "/var/run/hive/server2.pid", (err, running) ->
      callback err, running
  hive_server2_start: (ctx, callback) ->
    {hive_user, hive_log_dir, hive_pid_dir, hive_server2_host, hive_server2_port, hive_server2_timeout} = ctx.config.hdp
    lifecyle.hive_server2_status ctx, (err, running) ->
      return callback err, false if err or running
      ctx.execute
        # su -l hive -c 'nohup /usr/lib/hive/bin/hiveserver2 >/var/log/hive/hiveserver2.out 2>/var/log/hive/hiveserver2.log & echo $! >/var/run/hive/server2.pid'
        # su -l hive -c '/usr/lib/hive/bin/hiveserver2'
        cmd: "su -l #{hive_user} -c 'nohup /usr/lib/hive/bin/hiveserver2 >#{hive_log_dir}/hiveserver2.out 2>#{hive_log_dir}/hiveserver2.log & echo $! > /var/run/hive/server2.pid'"
        code_skipped: 1
      , (err, started) ->
        return callback err if err
        ctx.waitForConnection hive_server2_host, hive_server2_port, hive_server2_timeout, (err) ->
          callback err, started
  hive_server2_stop: (ctx, callback) ->
    {hive_user, hive_pid_dir} = ctx.config.hdp
    lifecyle.hive_server2_status ctx, (err, running) ->
      return callback err, false if err or not running
      ctx.execute
        # su -l hive -c "kill `cat /var/run/hive/server2.pid"
        cmd: "su -l #{hive_user} -c \"kill `cat #{hive_pid_dir}/server2.pid`\""
        code_skipped: 1
      , (err, started) ->
        callback err, started
  hive_server2_restart: (ctx, callback) ->
    lifecyle.hive_server2_stop ctx, (err) ->
      return callback err if err
      lifecyle.hive_server2_start ctx, callback
  oozie_status: (ctx, callback) ->
    {oozie_pid_dir} = ctx.config.hdp
    lifecyle.is_pidfile_running ctx, "#{oozie_pid_dir}/oozie.pid", (err, running) ->
      callback err, running
  oozie_start: (ctx, callback) ->
    {oozie_user} = ctx.config.hdp
    lifecyle.oozie_status ctx, (err, running) ->
      return callback err, false if err or running
      ctx.execute
        # su -l oozie -c "/usr/lib/oozie/bin/oozied.sh start"
        cmd: "su -l #{oozie_user} -c \"/usr/lib/oozie/bin/oozied.sh start\""
        code_skipped: 1
      , (err, started) ->
        callback err, started
  oozie_stop: (ctx, callback) ->
    {oozie_user} = ctx.config.hdp
    lifecyle.oozie_status ctx, (err, running) ->
      return callback err, false if err or not running
      ctx.execute
        # su -l oozie -c "/usr/lib/oozie/bin/oozied.sh stop"
        cmd: "su -l #{oozie_user} -c \"/usr/lib/oozie/bin/oozied.sh stop\""
        code_skipped: 1
      , (err, stoped) ->
        callback err, stoped
  zookeeper_start: (ctx, callback) ->
    {zookeeper_user, zookeeper_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l zookeeper -c "/usr/lib/zookeeper/bin/zkServer.sh start /etc/zookeeper/conf/zoo.cfg"
      cmd: "su -l #{zookeeper_user} -c \"/usr/lib/zookeeper/bin/zkServer.sh start #{zookeeper_conf_dir}/zoo.cfg\""
    , (err, stoped) ->
      callback err, stoped
  zookeeper_stop: (ctx, callback) ->
    {zookeeper_user, zookeeper_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l zookeeper -c "/usr/lib/zookeeper/bin/zkServer.sh stop /etc/zookeeper/conf/zoo.cfg"
      cmd: "su -l #{zookeeper_user} -c \"/usr/lib/zookeeper/bin/zkServer.sh stop #{zookeeper_conf_dir}/zoo.cfg\""
    , (err, stoped) ->
      callback err, stoped
  hbase_master_start: (ctx, callback) ->
    {hbase_user, hbase_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hbase -c "/usr/lib/hbase/bin/hbase-daemon.sh --config /etc/hbase/conf start master"
      cmd: "su -l #{hbase_user} -c \"/usr/lib/hbase/bin/hbase-daemon.sh --config #{hbase_conf_dir} start master\""
    , (err, stoped) ->
      callback err, stoped
  hbase_master_stop: (ctx, callback) ->
    {hbase_user, hbase_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hbase -c "/usr/lib/hbase/bin/hbase-daemon.sh --config /etc/hbase/conf stop master"
      cmd: "su -l #{hbase_user} -c \"/usr/lib/hbase/bin/hbase-daemon.sh --config #{hbase_conf_dir} stop master\""
    , (err, stoped) ->
      callback err, stoped
  hbase_regionserver_start: (ctx, callback) ->
    {hbase_user, hbase_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hbase -c "/usr/lib/hbase/bin/hbase-daemon.sh --config /etc/hbase/conf start regionserver"
      cmd: "su -l #{hbase_user} -c \"/usr/lib/hbase/bin/hbase-daemon.sh --config #{hbase_conf_dir} start regionserver\""
    , (err, started) ->
      callback err, started
  hbase_regionserver_stop: (ctx, callback) ->
    {hbase_user, hbase_conf_dir} = ctx.config.hdp
    ctx.execute
      # su -l hbase -c "/usr/lib/hbase/bin/hbase-daemon.sh --config /etc/hbase/conf stop regionserver"
      cmd: "su -l #{hbase_user} -c \"/usr/lib/hbase/bin/hbase-daemon.sh --config #{hbase_conf_dir} stop regionserver\""
    , (err, stoped) ->
      callback err, stoped
  webhcat_status: (ctx, callback) ->
    {webhcat_pid_dir} = ctx.config.hdp
    lifecyle.is_pidfile_running ctx, "#{webhcat_pid_dir}/webhcat.pid", (err, running) ->
      callback err, running
  webhcat_start: (ctx, callback) ->
    {webhcat_user, webhcat_conf_dir} = ctx.config.hdp
    lifecyle.webhcat_status ctx, (err, running) ->
      return callback err, false if err or running
      ctx.execute
        # su -l hcat -c "export WEBHCAT_CONF_DIR=/etc/hcatalog/conf/webhcat; /usr/lib/hcatalog/sbin/webhcat_server.sh start"
        cmd: "su -l #{webhcat_user} -c \"export WEBHCAT_CONF_DIR=#{webhcat_conf_dir}; /usr/lib/hcatalog/sbin/webhcat_server.sh start\""
      , (err, started) ->
        callback err, true
  webhcat_stop: (ctx, callback) ->
    {webhcat_user} = ctx.config.hdp
    lifecyle.webhcat_status ctx, (err, running) ->
      return callback err, false if err or not running
      ctx.execute
        # su -l hcat -c "/usr/lib/hcatalog/sbin/webhcat_server.sh stop"
        cmd: "su -l #{webhcat_user} -c \"/usr/lib/hcatalog/sbin/webhcat_server.sh stop\""
      , (err, stoped) ->
        callback err, stoped

module.exports.is_pidfile_running = (ctx, path, callback) ->
  ctx.execute
    cmd: """
    if pid=`cat #{path}`; then
      if ps cax | grep -v grep | grep $pid; then exit 0; else
        rm -f #{path}
    fi; fi; exit 1
    """
    code_skipped: 1
  , (err, started) ->
    callback err, started









