# Spark History Server

    module.exports = []

## Spark Configuration

    module.exports.configure = (ctx) ->
      require('../../hadoop/core').configure ctx
      {realm, core_site} = ctx.config.ryba
      spark = ctx.config.ryba.spark ?= {}
      # Layout
      spark.pid_dir ?= '/var/run/spark'
      spark.conf_dir ?= '/etc/spark/conf'
      spark.log_dir ?= '/var/log/spark'
      # https://spark.apache.org/docs/latest/monitoring.html
      spark.conf ?= {}
      spark.conf['spark.history.provider'] ?= 'org.apache.spark.deploy.history.FsHistoryProvider'
      spark.conf['spark.history.fs.update.interval'] ?= '10s'
      spark.conf['spark.history.retainedApplications'] ?= '50'
      spark.conf['spark.history.ui.port'] ?= '18080'
      spark.conf['spark.history.kerberos.enabled'] ?= if core_site['hadoop.http.authentication.type'] is 'kerberos' then 'true' else 'false'
      spark.conf['spark.history.kerberos.principal'] ?= "spark/#{ctx.config.host}@#{realm}"
      spark.conf['spark.history.kerberos.keytab'] ?= '/etc/security/keytabs/spark.keytab'
      spark.conf['spark.history.ui.acls.enable'] ?= ''
      spark.conf['spark.history.fs.cleaner.enabled'] ?= 'false'

    module.exports.push commands: 'check', modules: 'ryba/spark/history_server/check'

    module.exports.push commands: 'install', modules: [
      'ryba/spark/history_server/install'
      'ryba/spark/history_server/check'
      'ryba/spark/history_server/start'
    ]

    module.exports.push commands: 'status', modules: 'ryba/spark/history_server/status'

    module.exports.push commands: 'start', modules: 'ryba/spark/history_server/start'

    module.exports.push commands: 'stop', modules: 'ryba/spark/history_server/stop'
