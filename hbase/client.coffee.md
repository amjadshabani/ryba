
# HBase Client

    module.exports = []
    module.exports.push 'masson/bootstrap/'
    module.exports.push 'ryba/hbase/_'

    module.exports.push module.exports.configure = (ctx) ->
      require('./_').configure ctx
      hbase_site = ctx.config.hdp.hbase_site ?= {}
      hbase_site['hbase.security.authentication'] ?= 'kerberos'
      hbase_site['hbase.rpc.engine'] ?= 'org.apache.hadoop.hbase.ipc.SecureRpcEngine'
      ctx.config.hdp.shortname ?= ctx.config.shortname or ctx.config.host.split('.')[0]

## Zookeeper JAAS

JAAS configuration files for zookeeper to be deployed on the HBase Master, 
RegionServer, and HBase client host machines.

    module.exports.push name: 'HBase Client # Zookeeper JAAS', timeout: -1, callback: (ctx, next) ->
      {jaas_client, hbase_conf_dir, hbase_user, hbase_group} = ctx.config.hdp
      ctx.write
        destination: "#{hbase_conf_dir}/hbase-client.jaas"
        content: jaas_client
        uid: hbase_user.name
        gid: hbase_group.name
        mode: 0o700
      , (err, written) ->
        return next err, if written then ctx.OK else ctx.PASS

## Check

    module.exports.push 'ryba/hbase/client_check'


