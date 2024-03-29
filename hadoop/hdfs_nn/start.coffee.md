
# Hadoop HDFS NameNode Start

Start the NameNode service as well as its ZKFC daemon.

In HA mode, all JournalNodes shall be started.

    module.exports = []
    module.exports.push 'masson/bootstrap'
    module.exports.push 'ryba/xasecure/policymgr_wait'
    module.exports.push 'ryba/zookeeper/server/wait'
    module.exports.push 'ryba/hadoop/hdfs_jn/wait'
    # module.exports.push require('./index').configure

## Start Service

Start the HDFS NameNode Server. You can also start the server manually with the
following two commands:

```
service hadoop-hdfs-namenode start
su -l hdfs -c "/usr/hdp/current/hadoop-hdfs-namenode/../hadoop/sbin/hadoop-daemon.sh --config /etc/hadoop/conf --script hdfs start namenode"
```

    module.exports.push name: 'HDFS NN # Start', timeout: -1, label_true: 'STARTED', handler: ->
      @service_start
        name: 'hadoop-hdfs-namenode'
        if_exists: '/etc/init.d/hadoop-hdfs-namenode'

## Wait Safemode

Wait for HDFS safemode to exit. It isn't enough to start the NameNodes but the
majority of DataNodes also need to be running.

    module.exports.push 'ryba/hadoop/hdfs_nn/wait'
    # module.exports.push name: 'HDFS NN # Wait Safemode', timeout: -1, label_true: 'READY', handler: ->
    #   # return next() if @has_module 'ryba/hadoop/hdfs_dn'
    #   @wait_execute
    #     cmd: mkcmd.hdfs @, "hdfs dfsadmin -safemode get | grep OFF"
    #     interval: 3000

## Wait Failover

Ensure a given NameNode is always active and force the failover otherwise.

In order to work properly, the ZKFC daemon must be running and the command must
be executed on the same server as ZKFC.

This middleware duplicates the one present in 'ryba/hadoop/hdfs_dn/wait' and
is only called if a DataNode isn't installed on this server because this command
only run on a NameNode with fencing installed and in normal mode.

    module.exports.push name: 'HDFS NN Start # Failover', label_true: 'READY', handler: ->
      return next() unless @hosts_with_module('ryba/hadoop/hdfs_nn').length > 1
      {active_nn_host, standby_nn_host} = @config.ryba
      active_nn_host = active_nn_host.split('.')[0]
      standby_nn_host = standby_nn_host.split('.')[0]
      # This command seems to crash the standby namenode when it is made active and
      # when the active_nn is restarting and still in safemode
      @execute
        cmd: mkcmd.hdfs @, """
        if hdfs haadmin -getServiceState #{active_nn_host} | grep standby;
        then hdfs haadmin -failover #{standby_nn_host} #{active_nn_host};
        else exit 2; fi
        """
        code_skipped: 2

## Dependencies

    url = require 'url'
    mkcmd = require '../../lib/mkcmd'
