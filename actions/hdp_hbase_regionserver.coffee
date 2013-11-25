
lifecycle = require './hdp/lifecycle'
module.exports = []

module.exports.push 'histi/actions/hdp_hdfs'
module.exports.push 'histi/actions/hdp_zookeeper'
module.exports.push 'histi/actions/hdp_hbase'

# module.exports.push (ctx) ->
#   require('./hdp_hdfs').configure ctx
#   require('./hdp_hbase').configure ctx

module.exports.push (ctx, next) ->
  @name 'HDP HBase RegionServer # Kerberos'
  {realm, kadmin_principal, kadmin_password, kadmin_server} = ctx.config.krb5_client
  {hadoop_group, hbase_user, hbase_site} = ctx.config.hdp
  ctx.krb5_addprinc
    principal: hbase_site['hbase.regionserver.kerberos.principal'].replace '_HOST', ctx.config.host
    randkey: true
    keytab: hbase_site['hbase.regionserver.keytab.file']
    uid: hbase_user
    gid: hadoop_group
    kadmin_principal: kadmin_principal
    kadmin_password: kadmin_password
    kadmin_server: kadmin_server
  , (err, created) ->
    next err, if created then ctx.OK else ctx.PASS

module.exports.push (ctx, next) ->
  @name 'HDP HBase RegionServer # Start'
  lifecycle.hbase_regionserver_start ctx, (err, started) ->
    next err, if started then ctx.OK else ctx.PASS