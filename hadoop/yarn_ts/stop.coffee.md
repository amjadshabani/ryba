
# YARN Timeline Server Stop

    module.exports = []
    module.exports.push 'masson/bootstrap'

## Stop Server

Stop the HDFS Namenode service. You can also stop the server manually with one of
the following two commands:

```
service hadoop-yarn-timelineserver stop
su -l yarn -c "/usr/hdp/current/hadoop-yarn-timelineserver/sbin/yarn-daemon.sh --config /etc/hadoop/conf stop timelineserver"
```

    module.exports.push name: 'YARN TS # Stop Server', label_true: 'STOPPED', handler: ->
      @service_stop
        name: 'hadoop-yarn-timelineserver'
        if_exists: '/etc/init.d/hadoop-yarn-timelineserver'

    # module.exports.push name: 'YARN TS # Stop Clean Logs', label_true: 'CLEANED', handler: ->
    #   {clean_logs, yarn} = @config.ryba
    #   return next() unless clean_logs
    #   @execute
    #     cmd: 'rm #{yarn.log_dir}/*/*-nodemanager-*'
    #     code_skipped: 1
