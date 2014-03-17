
# HDFS JournalNode

In order for the Standby node to keep its state synchronized with the Active 
node, both nodes communicate with a group of separate daemons called 
"JournalNodes" (JNs). When any namespace modification is performed by the Active 
node, it durably logs a record of the modification to a majority of these JNs. 
The Standby node is capable of reading the edits from the JNs, and is constantly 
watching them for changes to the edit log.

The JournalNode daemon is relatively lightweight, so these daemons may reasonably 
be collocated on machines with other Hadoop daemons, for example NameNodes, the 
JobTracker, or the YARN ResourceManager.

There must be at least 3 JournalNode daemons, since edit log modifications must 
be written to a majority of JNs. To increase the number of failures a system
can tolerate, deploy an odd number of JNs because the system can tolerate at 
most (N - 1) / 2 failures to continue to function normally.

    lifecycle = require './lib/lifecycle'
    mkcmd = require './lib/mkcmd'
    module.exports = []
    module.exports.push 'phyla/hdp/hdfs'

## Configuration

The JournalNode uses properties define inside the "phyla/hdp/hdfs" module. It
also declare a new property "dfs.journalnode.edits.dir".

*   `hdp.hdfs_site['dfs.journalnode.edits.dir']` (string)   
    The directory where the JournalNode will write transaction logs, default
    to "/var/run/hadoop-hdfs/journalnode\_edit\_dir"

Example:

```json
{
  "hdp": {
    "hdfs_site": {
      "dfs.journalnode.edits.dir": "/var/run/hadoop-hdfs/journalnode\_edit\_dir"
    }
  }
}
```

    module.exports.push module.exports.configure = (ctx) ->
      require('./hdfs').configure ctx
      ctx.config.hdp.hdfs_site['dfs.journalnode.edits.dir'] ?= '/var/run/hadoop-hdfs/journalnode_edit_dir'

## Layout

The layout consisit of the directory define by the "dfs.journalnode.edits.dir"
property.

    module.exports.push name: 'HDP HDFS JN # Layout', callback: (ctx, next) ->
      {hdfs_site, hadoop_conf_dir} = ctx.config.hdp
      ctx.mkdir
        destination: hdfs_site['dfs.journalnode.edits.dir']
        uid: 'hdfs'
        gid: 'hadoop'
      , (err, created) ->
        return next err if err
        next null, if created then ctx.OK else ctx.PASS

## Configure

Update the "hdfs-site.xml" file with the "dfs.journalnode.edits.dir" property.

    module.exports.push name: 'HDP HDFS JN # Configure', callback: (ctx, next) ->
      {hdfs_site, hadoop_conf_dir} = ctx.config.hdp
      ctx.hconfigure
        destination: "#{hadoop_conf_dir}/hdfs-site.xml"
        properties: hdfs_site
        merge: true
      , (err, configured) ->
        return next err if err
        next null, if configured then ctx.OK else ctx.PASS

## Kerberos

Register the SPNEGO service principal in the form of "HTTP/{host}@{realm}" into 
the "hdfs-site.xml" file. The impacted properties are "dfs.journalnode.kerberos.internal.spnego.principal", 
"dfs.journalnode.kerberos.principal" and "dfs.journalnode.keytab.file". The SPNEGO 
tocken is stored inside the "/etc/security/keytabs/spnego.service.keytab" keytab, 
also used by the NameNodes, DataNodes, ResourceManagers and NodeManagers.

    module.exports.push name: 'HDP HDFS JN # Kerberos', callback: (ctx, next) ->
      {hadoop_conf_dir} = ctx.config.hdp
      {realm} = ctx.config.krb5_client
      hdfs_site = {}
      # hdfs_site['dfs.journalnode.http-address'] = '0.0.0.0:8480'
      hdfs_site['dfs.journalnode.kerberos.internal.spnego.principal'] = "HTTP/_HOST@#{realm}"
      hdfs_site['dfs.journalnode.kerberos.principal'] = "HTTP/_HOST@#{realm}"
      hdfs_site['dfs.journalnode.keytab.file'] = '/etc/security/keytabs/spnego.service.keytab'
      ctx.hconfigure
        destination: "#{hadoop_conf_dir}/hdfs-site.xml"
        properties: hdfs_site
        merge: true
      , (err, configured) ->
        next err, if configured then ctx.OK else ctx.PASS

## Start

Load the module "phyla/hdp/hdfs\_jn\_start" to start the JournalNode.

    module.exports.push 'phyla/hdp/hdfs_jn_start'



