
# Nagios Check

```
# HDFS::Blocks health
php /usr/lib64/nagios/plugins/check_hdfs_blocks.php \
  -h master1.hadoop,master2.hadoop -p 50470 -s FSNamesystem \
  -e true -k /etc/security/keytabs/nagios.service.keytab \
  -r nagios/master1.hadoop@HADOOP.ADALTAS.COM -t /usr/bin/kinit -u true
# HDFS::NameNode RPC latency
php /usr/lib64/nagios/plugins/check_rpcq_latency_ha.php \
  -h master1.hadoop,master2.hadoop -p 50470 -n NameNode -w 3000 -c 5000 -e true \
  -k /etc/security/keytabs/nagios.service.keytab \
  -r nagios/master1.hadoop@HADOOP.ADALTAS.COM \
  -t /usr/bin/kinit -s true
# RESOURCEMANAGER::ResourceManager RPC latency
php /usr/lib64/nagios/plugins/check_rpcq_latency_ha.php \
  -h master2.hadoop -p 8090 -n ResourceManager -w 3000 -c 5000 -e true \
  -k /etc/security/keytabs/nagios.service.keytab \
  -r nagios/master1.hadoop@HADOOP.ADALTAS.COM \
  -t /usr/bin/kinit -s true
# NODEMANAGER::NodeManager process
/usr/lib64/nagios/plugins/check_tcp \
  -H worker1.hadoop -p 8044 -w 1 -c 1
# NODEMANAGER::NodeManager health
/usr/lib64/nagios/plugins/check_nodemanager_health.sh \
  worker1.hadoop 8044 true true \
  /etc/security/keytabs/nagios.service.keytab \
  nagios/master1.hadoop@HADOOP.ADALTAS.COM /usr/bin/kinit
# HIVE-SERVER::HiveServer2 process
/usr/lib64/nagios/plugins/check_tcp \
  -H master3.hadoop -p 10001 -w 1 -c 1 \
  -s "A001 AUTHENTICATE ANONYMOUS"
# OOZIE::Oozie Server status
/usr/lib64/nagios/plugins/check_oozie_status.sh \
  master3.hadoop 11000 /usr/lib/jvm/java true \
  /etc/security/keytabs/nagios.service.keytab \
  nagios/master1.hadoop@HADOOP.ADALTAS.COM \
  /usr/bin/kinit
# HUE::Hue Server status
/usr/lib64/nagios/plugins/check_hue_status.sh
```

    module.exports = []
    module.exports.push 'masson/bootstrap'
    # module.exports.push require('./index').configure

    module.exports.push name: 'Nagios # Check Config', label_true: 'CHECKED', handler: ->
      @execute
        cmd: "nagios -v /etc/nagios/nagios.cfg"
        code_skipped: 254
      , (err, executed, stdout) ->
        throw err if err
        throw Error "Nagios Invalid Configuration" unless executed
        errors = /Total Errors:\s+(\d+)/.exec(stdout)?[1]
        throw Error "Nagios Errors: #{errors}" unless errors is '0'

    module.exports.push name: 'Nagios # Check Command', label_true: 'CHECKED', handler: ->
      {kinit} = @config.krb5
      {active_nn_host, nameservice, core_site, hdfs, nagios} = @config.ryba
      protocol = if hdfs.site['dfs.http.policy'] is 'HTTP_ONLY' then 'http' else 'https'
      unless @hosts_with_module('ryba/hadoop/hdfs_nn').length > 1
        nn_host = @host_with_module 'ryba/hadoop/hdfs_nn'
        nn_port = hdfs.site['dfs.namenode.https-address'].split(':')[1]
      else
        nn_host = active_nn_host
        shortname = @hosts[active_nn_host].config.shortname
        nn_port = @config.ryba.hdfs.site["dfs.namenode.#{protocol}-address.#{nameservice}.#{shortname}"].split(':')[1]
      cmd = "php /usr/lib64/nagios/plugins/check_hdfs_capacity.php"
      cmd += " -h #{nn_host}"
      cmd += " -p #{nn_port}"
      cmd += " -w 80%"
      cmd += " -c 90%"
      cmd += " -k #{nagios.keytab}"
      cmd += " -r #{nagios.principal}"
      cmd += " -t #{kinit}"
      cmd += " -e #{if core_site['hadoop.security.authentication'] is 'kerberos' then 'true' else 'false'}"
      cmd += " -s #{if protocol is 'https' then 'true' else 'false'}"
      @execute
        cmd: cmd

## Dependencies

    url = require 'url'
