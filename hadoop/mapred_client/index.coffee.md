
# MapReduce Client

MapReduce is the key algorithm that the Hadoop MapReduce engine uses to distribute work around a cluster.
The key aspect of the MapReduce algorithm is that if every Map and Reduce is independent of all other ongoing Maps and Reduces,
then the operation can be run in parallel on different keys and lists of data. On a large cluster of machines, you can go one step further, and run the Map operations on servers where the data lives.
Rather than copy the data over the network to the program, you push out the program to the machines.
The output list can then be saved to the distributed filesystem, and the reducers run to merge the results. Again, it may be possible to run these in parallel, each reducing different keys.

    module.exports = []

    module.exports.configure = ->
      return if @mapred_configured
      @mapred_configured = true
      require('../hdfs').configure @
      require('../yarn_client').configure @
      rm_contexts = @contexts 'ryba/hadoop/yarn_rm', require('../yarn_rm').configure
      {static_host, realm, mapred} = @config.ryba
      # Layout
      mapred.pid_dir ?= '/var/run/hadoop-mapreduce'  # /etc/hadoop/conf/hadoop-env.sh#94
      # Configuration
      mapred.site['mapreduce.job.counters.max'] ?= 120
      mapred.site['mapreduce.reduce.shuffle.parallelcopies'] ?= '50' #  Higher number of parallel copies run by reduces to fetch outputs from very large number of maps.
      # http://docs.hortonworks.com/HDPDocuments/HDP2/HDP-2.0.6.0/bk_installing_manually_book/content/rpm_chap3.html
      # Optional: Configure MapReduce to use Snappy Compression
      # Complement core-site.xml configuration
      # mapred.site['mapreduce.admin.map.child.java.opts'] ?= "-server -XX:NewRatio=8 -Djava.library.path=/usr/lib/hadoop/lib/native/ -Djava.net.preferIPv4Stack=true"
      mapred.site['mapreduce.admin.map.child.java.opts'] ?= "-server -Djava.net.preferIPv4Stack=true -Dhdp.version=${hdp.version}"
      mapred.site['mapreduce.admin.reduce.child.java.opts'] ?= null
      mapred.site['mapreduce.task.io.sort.factor'] ?= 100 # Default to "TODO..." inside HPD and 100 inside ambari and 10 inside mapred-default.xml
      # mapred.site['mapreduce.admin.reduce.child.java.opts'] ?= "-server -XX:NewRatio=8 -Djava.library.path=/usr/lib/hadoop/lib/native/ -Djava.net.preferIPv4Stack=true"
      mapred.site['mapreduce.admin.user.env'] ?= "LD_LIBRARY_PATH=/usr/hdp/${hdp.version}/hadoop/lib/native:/usr/hdp/${hdp.version}/hadoop/lib/native/Linux-amd64-64"
      # [Configurations for MapReduce JobHistory Server](http://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/ClusterSetup.html#Configuring_the_Hadoop_Daemons_in_Non-Secure_Mode)
      mapred.site['mapreduce.application.framework.path'] ?= "/hdp/apps/${hdp.version}/mapreduce/mapreduce.tar.gz#mr-framework"
      mapred.site['mapreduce.application.classpath'] ?= "$PWD/mr-framework/hadoop/share/hadoop/mapreduce/*:$PWD/mr-framework/hadoop/share/hadoop/mapreduce/lib/*:$PWD/mr-framework/hadoop/share/hadoop/common/*:$PWD/mr-framework/hadoop/share/hadoop/common/lib/*:$PWD/mr-framework/hadoop/share/hadoop/yarn/*:$PWD/mr-framework/hadoop/share/hadoop/yarn/lib/*:$PWD/mr-framework/hadoop/share/hadoop/hdfs/*:$PWD/mr-framework/hadoop/share/hadoop/hdfs/lib/*:/usr/hdp/${hdp.version}/hadoop/lib/hadoop-lzo-0.6.0.${hdp.version}.jar:/etc/hadoop/conf/secure"
      [jhs_context] = @contexts 'ryba/hadoop/mapred_jhs', require('../mapred_jhs').configure
      if jhs_context
        for property in [
          'yarn.app.mapreduce.am.staging-dir'
          'mapreduce.jobhistory.address'
          'mapreduce.jobhistory.webapp.address'
          'mapreduce.jobhistory.webapp.https.address'
          'mapreduce.jobhistory.done-dir'
          'mapreduce.jobhistory.intermediate-done-dir'
          'mapreduce.jobhistory.principal'
        ]
          mapred.site[property] ?= jhs_context.config.ryba.mapred.site[property]
        # mapred.site['yarn.app.mapreduce.am.staging-dir'] ?= jhs_context.config.ryba.mapred.site['mapreduce.jobhistory.address']
        # mapred.site['mapreduce.jobhistory.address'] ?= jhs_context.config.ryba.mapred.site['mapreduce.jobhistory.address']
        # mapred.site['mapreduce.jobhistory.webapp.address'] ?= jhs_context.config.ryba.mapred.site['mapreduce.jobhistory.webapp.address']
        # mapred.site['mapreduce.jobhistory.webapp.https.address'] ?= jhs_context.config.ryba.mapred.site['mapreduce.jobhistory.webapp.https.address']
        # mapred.site['mapreduce.jobhistory.done-dir'] ?= jhs_context.config.ryba.mapred.site['mapreduce.jobhistory.done-dir']
        # mapred.site['mapreduce.jobhistory.intermediate-done-dir'] ?= jhs_context.config.ryba.mapred.site['mapreduce.jobhistory.intermediate-done-dir']
        # # Important, JHS principal must be deployed on all mapreduce workers
        # mapred.site['mapreduce.jobhistory.principal'] ?= "jhs/#{jhs_context.config.host}@#{realm}"
      # The value is set by the client app and the iptables are enforced on the worker nodes
      mapred.site['yarn.app.mapreduce.am.job.client.port-range'] ?= '59100-59200'
      mapred.site['mapreduce.framework.name'] ?= 'yarn' # Execution framework set to Hadoop YARN.
      # Deprecated properties
      mapred.site['mapreduce.cluster.local.dir'] = null # Now "yarn.nodemanager.local-dirs"
      mapred.site['mapreduce.jobtracker.system.dir'] = null # JobTracker no longer used

# Configuration for Resource Allocation

There are three aspects to consider:

*   Physical RAM limit for each Map And Reduce task
*   The JVM heap size limit for each task
*   The amount of virtual memory each task will get

The total size of the memory given to the JVM available to each map/reduce
container is defined by the properties "mapreduce.map.memory.mb" and
"mapreduce.reduce.memory.mb" in megabytes (MB). This includes both heap memory
(which many of us Java developers always are thinking about) and non-heap
memory. Non-heap memory includes the stack and the PermGen space. It should be
at least equal to or more than the YARN minimum Container allocation.

For this reason, the maximum size of the heap (Java -Xmx parameter) is set to an
inferior value, commonly 80% of the maximum available memory. The heap size
parameter is defined inside the "mapreduce.map.java.opts" and
"mapreduce.reduce.java.opts" properties.

      memory_per_container = 512
      rm_memory_min_mb = rm_contexts[0].config.ryba.yarn.site['yarn.scheduler.minimum-allocation-mb']
      rm_memory_max_mb = rm_contexts[0].config.ryba.yarn.site['yarn.scheduler.maximum-allocation-mb']
      rm_cpu_min = rm_contexts[0].config.ryba.yarn.site['yarn.scheduler.minimum-allocation-vcores']
      rm_cpu_max = rm_contexts[0].config.ryba.yarn.site['yarn.scheduler.maximum-allocation-mb']
      yarn_mapred_am_memory_mb = mapred.site['yarn.app.mapreduce.am.resource.mb'] or if memory_per_container > 1024 then 2 * memory_per_container else memory_per_container
      yarn_mapred_am_memory_mb = Math.min rm_memory_max_mb, yarn_mapred_am_memory_mb
      mapred.site['yarn.app.mapreduce.am.resource.mb'] = "#{yarn_mapred_am_memory_mb}"

      yarn_mapred_opts = /-Xmx(.*?)m/.exec(mapred.site['yarn.app.mapreduce.am.command-opts'])?[1] or Math.floor(.8 * yarn_mapred_am_memory_mb)
      yarn_mapred_opts = Math.min rm_memory_max_mb, yarn_mapred_opts
      mapred.site['yarn.app.mapreduce.am.command-opts'] = "-Xmx#{yarn_mapred_opts}m"

      map_memory_mb = mapred.site['mapreduce.map.memory.mb'] or memory_per_container
      map_memory_mb = Math.min rm_memory_max_mb, map_memory_mb
      map_memory_mb = Math.max rm_memory_min_mb, map_memory_mb
      mapred.site['mapreduce.map.memory.mb'] = "#{map_memory_mb}"

      reduce_memory_mb = mapred.site['mapreduce.reduce.memory.mb'] or memory_per_container #2 * memory_per_container
      reduce_memory_mb = Math.min rm_memory_max_mb, reduce_memory_mb
      reduce_memory_mb = Math.max rm_memory_min_mb, reduce_memory_mb
      mapred.site['mapreduce.reduce.memory.mb'] = "#{reduce_memory_mb}"

      map_memory_xmx = /-Xmx(.*?)m/.exec(mapred.site['mapreduce.map.java.opts'])?[1] or Math.floor .8 * map_memory_mb
      map_memory_xmx = Math.min rm_memory_max_mb, map_memory_xmx
      mapred.site['mapreduce.map.java.opts'] ?= "-Xmx#{map_memory_xmx}m"

      reduce_memory_xmx = /-Xmx(.*?)m/.exec(mapred.site['mapreduce.reduce.java.opts'])?[1] or Math.floor .8 * reduce_memory_mb
      reduce_memory_xmx = Math.min rm_memory_max_mb, reduce_memory_xmx
      mapred.site['mapreduce.reduce.java.opts'] ?= "-Xmx#{reduce_memory_xmx}m"

      mapred.site['mapreduce.task.io.sort.mb'] ?= "#{Math.floor .4 * memory_per_container}"

      map_cpu = mapred.site['mapreduce.map.cpu.vcores'] or 1
      map_cpu = Math.min rm_cpu_max, map_cpu
      map_cpu = Math.max rm_cpu_min, map_cpu
      mapred.site['mapreduce.map.cpu.vcores'] = "#{map_cpu}"

      reduce_cpu = mapred.site['mapreduce.reduce.cpu.vcores'] or 1
      reduce_cpu = Math.min rm_cpu_max, reduce_cpu
      reduce_cpu = Math.max rm_cpu_min, reduce_cpu
      mapred.site['mapreduce.reduce.cpu.vcores'] = "#{reduce_cpu}"


    module.exports.push commands: 'check', modules: 'ryba/hadoop/mapred_client/check'

    module.exports.push commands: 'report', modules: 'ryba/hadoop/mapred_client/report'

    module.exports.push commands: 'install', modules: [
      'ryba/hadoop/mapred_client/install'
      'ryba/hadoop/mapred_client/check'
    ]

[beadooper]: http://beadooper.com/?p=165
