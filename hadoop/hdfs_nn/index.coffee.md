
# Hadoop HDFS NameNode

NameNode’s primary responsibility is storing the HDFS namespace. This means things
like the directory tree, file permissions, and the mapping of files to block
IDs. It tracks where across the cluster the file data is kept on the DataNodes. It
does not store the data of these files itself. It’s important that this metadata
(and all changes to it) are safely persisted to stable storage for fault tolerance.

    module.exports = []

## Configuration

Look at the file [DFSConfigKeys.java][keys] for an exhaustive list of supported
properties.

*   `ryba.hdfs.site` (object)
    Properties added to the "hdfs-site.xml" file.
*   `ryba.hdfs.namenode_opts` (string)
    NameNode options.

Example:

```json
{
  "ryba": {
    "hdfs": {
      "namenode_opts": "-Xms1024m -Xmx1024m",
      "include": ["in.my.cluster"],
      "exclude": "not.in.my.cluster"
    }
  }
}
```

    module.exports.configure = (ctx) ->
      if ctx.hdfs_nn_configured then return else ctx.hdfs_nn_configured = true
      require('masson/core/iptables').configure ctx
      require('../hdfs').configure ctx
      {ryba} = ctx.config
      # throw Error "Missing \"ryba.zkfc_password\" property" unless ryba.zkfc_password
      # Data
      # Comma separated list of paths. Use the list of directories.
      # For example, /data/1/hdfs/nn,/data/2/hdfs/nn.
      ryba.hdfs.site['dfs.namenode.name.dir'] ?= ['file:///var/hdfs/name']
      ryba.hdfs.site['dfs.namenode.name.dir'] = ryba.hdfs.site['dfs.namenode.name.dir'].join ',' if Array.isArray ryba.hdfs.site['dfs.namenode.name.dir']
      # Network
      ryba.hdfs.site['dfs.hosts'] ?= "#{ryba.hadoop_conf_dir}/dfs.include"
      ryba.hdfs.include ?= ctx.hosts_with_module 'ryba/hadoop/hdfs_dn'
      ryba.hdfs.include = string.lines ryba.hdfs.include if typeof ryba.hdfs.include is 'string'
      ryba.hdfs.site['dfs.hosts.exclude'] ?= "#{ryba.hadoop_conf_dir}/dfs.exclude"
      ryba.hdfs.exclude ?= []
      ryba.hdfs.exclude = string.lines ryba.hdfs.exclude if typeof ryba.hdfs.exclude is 'string'
      unless ctx.hosts_with_module('ryba/hadoop/hdfs_nn').length > 1
        ryba.hdfs.site['dfs.namenode.http-address'] ?= '0.0.0.0:50070'
        ryba.hdfs.site['dfs.namenode.https-address'] ?= '0.0.0.0:50470'
      else
        # HDFS HA configuration
        namenodes = ctx.hosts_with_module 'ryba/hadoop/hdfs_nn'
        ctx.config.ryba.shortname ?= ctx.config.shortname
        ryba.hdfs.site['dfs.nameservices'] = ryba.nameservice
        ryba.hdfs.site["dfs.ha.namenodes.#{ryba.nameservice}"] = (for nn in namenodes then nn.split('.')[0]).join ','
        for nn in namenodes
          ryba.hdfs.site['dfs.namenode.http-address'] = null
          ryba.hdfs.site['dfs.namenode.https-address'] = null
          hconfig = ctx.hosts[nn].config
          shortname = hconfig.ryba.shortname ?= hconfig.shortname or nn.split('.')[0]
          ryba.hdfs.site["dfs.namenode.rpc-address.#{ryba.nameservice}.#{shortname}"] ?= "#{nn}:8020"
          ryba.hdfs.site["dfs.namenode.http-address.#{ryba.nameservice}.#{shortname}"] ?= "#{nn}:50070"
          ryba.hdfs.site["dfs.namenode.https-address.#{ryba.nameservice}.#{shortname}"] ?= "#{nn}:50470"
        ryba.hdfs.site["dfs.client.failover.proxy.provider.#{ryba.nameservice}"] ?= 'org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider'
      # Kerberos
      ryba.hdfs.site['dfs.namenode.kerberos.principal'] ?= "nn/#{ryba.static_host}@#{ryba.realm}"
      ryba.hdfs.site['dfs.namenode.keytab.file'] ?= '/etc/security/keytabs/nn.service.keytab'
      ryba.hdfs.site['dfs.namenode.kerberos.internal.spnego.principal'] ?= "HTTP/#{ryba.static_host}@#{ryba.realm}"
      ryba.hdfs.site['dfs.namenode.kerberos.https.principal'] = "HTTP/#{ryba.static_host}@#{ryba.realm}"
      ryba.hdfs.site['dfs.web.authentication.kerberos.principal'] ?= "HTTP/#{ryba.static_host}@#{ryba.realm}"
      ryba.hdfs.site['dfs.web.authentication.kerberos.keytab'] ?= '/etc/security/keytabs/spnego.service.keytab'
      # Fix HDP Companion File bug
      ryba.hdfs.site['dfs.https.namenode.https-address'] = null
      # Activate ACLs
      ryba.hdfs.site['dfs.namenode.acls.enabled'] ?= 'true'
      ryba.hdfs.site['dfs.namenode.accesstime.precision'] ?= null
      # NameNode options
      ryba.hdfs.namenode_opts ?= ''

## Configuration for HDFS High Availability (HA)

Add High Availability specific properties to the "hdfs-site.xml" file. The
inserted properties are similar than the ones for a client or slave
configuration with the additionnal "dfs.namenode.shared.edits.dir" property.

The default configuration implement the "sshfence" fencing method. This method
SSHes to the target node and uses fuser to kill the process listening on the
service's TCP port.

      if ctx.hosts_with_module('ryba/hadoop/hdfs_nn').length > 1
        ryba.hdfs.site['dfs.ha.automatic-failover.enabled'] ?= 'true'
        journalnodes = ctx.hosts_with_module 'ryba/hadoop/hdfs_jn'
        ryba.hdfs.site['dfs.namenode.shared.edits.dir'] = (for jn in journalnodes then "#{jn}:8485").join ';'
        ryba.hdfs.site['dfs.namenode.shared.edits.dir'] = "qjournal://#{ryba.hdfs.site['dfs.namenode.shared.edits.dir']}/#{ryba.hdfs.site['dfs.nameservices']}"
        # Fencing
        ryba.hdfs.site['dfs.ha.fencing.methods'] ?= "sshfence(#{ryba.hdfs.user.name})"
        ryba.hdfs.site['dfs.ha.fencing.ssh.private-key-files'] ?= "#{ryba.hdfs.user.home}/.ssh/id_rsa"

    module.exports.client_config = (ctx) ->
      {ryba} = ctx.config
      # Import properties from NameNode
      [nn_ctx] = ctx.contexts 'ryba/hadoop/hdfs_nn', require('./index').configure
      properties = [
        'dfs.namenode.kerberos.principal'
        'dfs.namenode.kerberos.internal.spnego.principal'
        'dfs.namenode.kerberos.https.principal'
        'dfs.web.authentication.kerberos.principal'
        'dfs.ha.automatic-failover.enabled'
        'dfs.nameservices'
      ]
      for property in properties
        ryba.hdfs.site[property] ?= nn_ctx.config.ryba.hdfs.site[property]
      for property of nn_ctx.config.ryba.hdfs.site
        ok = false
        ok = true if /^dfs\.namenode\.\w+-address/.test property
        ok = true if property.indexOf('dfs.client.failover.proxy.provider.') is 0
        ok = true if property.indexOf('dfs.ha.namenodes.') is 0
        continue unless ok
        ryba.hdfs.site[property] ?= nn_ctx.config.ryba.hdfs.site[property]

## Commands

    module.exports.push commands: 'backup', modules: 'ryba/hadoop/hdfs_nn/backup'

    module.exports.push commands: 'check', modules: 'ryba/hadoop/hdfs_nn/check'

    module.exports.push commands: 'install', modules: [
      'ryba/hadoop/hdfs_nn/install'
      'ryba/hadoop/hdfs_nn/start'
      'ryba/hadoop/hdfs_nn/layout'
      'ryba/hadoop/hdfs_nn/check'
    ]

    module.exports.push commands: 'start', modules: 'ryba/hadoop/hdfs_nn/start'

    module.exports.push commands: 'status', modules: 'ryba/hadoop/hdfs_nn/status'

    module.exports.push commands: 'stop', modules: 'ryba/hadoop/hdfs_nn/stop'

## Dependencies

    string = require 'mecano/lib/misc/string'

[keys]: https://github.com/apache/hadoop-common/blob/trunk/hadoop-hdfs-project/hadoop-hdfs/src/main/java/org/apache/hadoop/hdfs/DFSConfigKeys.java
