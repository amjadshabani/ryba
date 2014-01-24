
mecano = require 'mecano'
module.exports = []

# su -l hdfs -c "/usr/lib/hadoop/bin/hadoop-daemon.sh --config /etc/hadoop/conf start namenode"
# su $HDFS_USER; /usr/lib/hadoop/bin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start secondarynamenode
# su $HDFS_USER; /usr/lib/hadoop/bin/hadoop-daemon.sh --config $HADOOP_CONF_DIR start datanode

module.exports.push name: 'Ambari Server # Start', timeout: -1, callback: (ctx, next) ->
  ctx.service
    name: 'ambari-server'
    action: 'start'
  , (err, started) ->
    next err, if started then ctx.OK else ctx.PASS

