
# Hive Server2 Start

The Hive HCatalog require the database server to be started. The Hive Server2
require the HFDS Namenode to be started. Both of them will need to functionnal
HDFS server to answer queries.

    module.exports = []
    module.exports.push 'masson/bootstrap'
    module.exports.push 'ryba/hive/hcatalog/wait'

## Start

Start the Hive Server2. You can also start the server manually with one of the
following two commands:

```
service hive-server2 start
su -l hive -c 'nohup /usr/hdp/current/hive/bin/hiveserver2 >/var/log/hive/hiveserver2.out 2>/var/log/hive/hiveserver2.log & echo $! >/var/run/hive/server2.pid'
```

    module.exports.push name: 'Hive Server2 # Start', timeout: -1, label_true: 'STARTED', handler: ->
      @service_start
        name: 'hive-server2'
