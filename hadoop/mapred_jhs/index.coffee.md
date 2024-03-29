
# MapReduce JobHistoryServer(JHS)
The mapreduce job history server helps you to keep track about every job launched in the cluster.
Tje job history server gather information for all jobs launched on every distinct server and can be found ( once you kerbos ticket initiated) [here](http://master1.ryba:19888/jobhistory) for example
replace master2.ryba by the address of the server where the server is installed, or by its alias.
Now the jobHistory Server tends to be replace by the Yarn timeline server.


    module.exports = []

## Configuration

    module.exports.configure = (ctx) ->
      require('masson/core/iptables').configure ctx
      require('../yarn_client').configure ctx
      # require('./mapred').configure ctx
      {ryba} = ctx.config
      ryba.mapred ?= {}
      ryba.mapred.heapsize ?= '900'
      ryba.mapred.pid_dir ?= '/var/run/hadoop-mapreduce'  # /etc/hadoop/conf/hadoop-env.sh#94
      ryba.mapred.log_dir ?= '/var/log/hadoop-mapreduce' # required by hadoop-env.sh
      ryba.mapred.site ?= {}
      ryba.mapred.site['mapreduce.jobhistory.keytab'] ?= "/etc/security/keytabs/jhs.service.keytab"
      ryba.mapred.site['mapreduce.jobhistory.principal'] ?= "jhs/#{ctx.config.host}@#{ryba.realm}"
      # Fix: src in "[DFSConfigKeys.java][keys]" and [HDP port list] mention 13562 while companion files mentions 8081
      ryba.mapred.site['mapreduce.shuffle.port'] ?= '13562'
      ryba.mapred.site['mapreduce.jobhistory.address'] ?= "#{ctx.config.host}:10020"
      ryba.mapred.site['mapreduce.jobhistory.webapp.address'] ?= "#{ctx.config.host}:19888"
      ryba.mapred.site['mapreduce.jobhistory.webapp.https.address'] ?= "#{ctx.config.host}:19889"
      ryba.mapred.site['mapreduce.jobhistory.admin.address'] ?= "#{ctx.config.host}:10033"

Note: As of version "2.4.0", the property "mapreduce.jobhistory.http.policy"
isn't honored. Instead, the property "yarn.http.policy" is used.

      # ryba.mapred.site['mapreduce.jobhistory.http.policy'] ?= 'HTTPS_ONLY' # 'HTTP_ONLY' or 'HTTPS_ONLY'
      rm_contexts = ctx.contexts modules: 'ryba/hadoop/yarn_rm', require('../yarn_rm').configure
      ryba.yarn.site['yarn.http.policy'] ?= rm_contexts[0].config.ryba.yarn.site['yarn.http.policy']
      ryba.mapred.site['mapreduce.jobhistory.http.policy'] ?= rm_contexts[0].config.ryba.yarn.site['yarn.http.policy']
      # See './hadoop-mapreduce-project/hadoop-mapreduce-client/hadoop-mapreduce-client-common/src/main/java/org/apache/hadoop/mapreduce/v2/jobhistory/JHAdminConfig.java#158'
      # yarn.site['mapreduce.jobhistory.webapp.spnego-principal']
      # yarn.site['mapreduce.jobhistory.webapp.spnego-keytab-file']

## Configuration for Staging Directories

The property "yarn.app.mapreduce.am.staging-dir" is an alternative to "done-dir"
and "intermediate-done-dir". According to Cloudera](): Configure 
mapreduce.jobhistory.intermediate-done-dir and mapreduce.jobhistory.done-dir in
mapred-site.xml. Create these two directories. Set permissions on
mapreduce.jobhistory.intermediate-done-dir to 1777. Set permissions on
mapreduce.jobhistory.done-dir to 750.

If "yarn.app.mapreduce.am.staging-dir" is active (if the other two are unset),
a folder history must be created and own by the mapreduce user. On startup, JHS
will create two folders:

```bash
hdfs dfs -ls /user/history
Found 2 items
drwxrwx---   - mapred hadoop          0 2015-08-04 23:21 /user/history/done
drwxrwxrwt   - mapred hadoop          0 2015-08-04 23:21 /user/history/done_intermediate
```

      ryba.mapred.site['yarn.app.mapreduce.am.staging-dir'] = "/user" # default to "/tmp/hadoop-yarn/staging"
      # ryba.mapred.site['mapreduce.jobhistory.done-dir'] ?= '/mr-history/done' # Directory where history files are managed by the MR JobHistory Server.
      # ryba.mapred.site['mapreduce.jobhistory.intermediate-done-dir'] ?= '/mr-history/tmp' # Directory where history files are written by MapReduce jobs.
      ryba.mapred.site['mapreduce.jobhistory.done-dir'] = null
      ryba.mapred.site['mapreduce.jobhistory.intermediate-done-dir'] = null


## Job Recovery

The following properties provides persistent state to the Job history server.
They are referenced by [the druid hadoop configuration][druid] and
[the Ambari 2.3 stack][amb-mr-site]. Job Recovery is activated by default.   

      ryba.mapred.site['mapreduce.jobhistory.recovery.enable'] ?= 'true'
      ryba.mapred.site['mapreduce.jobhistory.recovery.store.class'] ?= 'org.apache.hadoop.mapreduce.v2.hs.HistoryServerLeveldbStateStoreService'
      ryba.mapred.site['mapreduce.jobhistory.recovery.store.leveldb.path'] ?= '/var/mapred/jhs'

## Commands

    # module.exports.push commands: 'backup', modules: 'ryba/hadoop/mapred_jhs/backup'

    # module.exports.push commands: 'check', modules: 'ryba/hadoop/mapred_jhs/check'

    module.exports.push commands: 'install', modules: [
      'ryba/hadoop/mapred_jhs/install'
      'ryba/hadoop/mapred_jhs/start'
      'ryba/hadoop/mapred_jhs/check'
    ]

    module.exports.push commands: 'start', modules: 'ryba/hadoop/mapred_jhs/start'

    module.exports.push commands: 'status', modules: 'ryba/hadoop/mapred_jhs/status'

    module.exports.push commands: 'stop', modules: 'ryba/hadoop/mapred_jhs/stop'

[druid]: http://druid.io/docs/latest/configuration/hadoop.html
[amb-mr-site]: https://github.com/apache/ambari/blob/trunk/ambari-server/src/main/resources/stacks/HDP/2.3/services/YARN/configuration-mapred/mapred-site.xml


