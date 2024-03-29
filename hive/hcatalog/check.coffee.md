
# Hive HCatalog Check

    module.exports = []
    module.exports.push 'masson/bootstrap'
    module.exports.push 'ryba/hive/hcatalog/wait'
    # module.exports.push require('./index').configure

## Check Database

Check if Hive can authenticate and run a basic query to the database.

    module.exports.push name: 'Hive HCatalog # Check Database', label_true: 'CHECKED', handler: ->
      {hive, db_admin} = @config.ryba
      username = hive.site['javax.jdo.option.ConnectionUserName']
      password = hive.site['javax.jdo.option.ConnectionPassword']
      {engine, db} = parse_jdbc hive.site['javax.jdo.option.ConnectionURL']
      switch engine
        when 'mysql'
          escape = (text) -> text.replace(/[\\"]/g, "\\$&")
          cmd = " "
          @execute
            cmd: """
            #{db_admin.path} -u#{db_admin.username} -p#{db_admin.password} -h#{db_admin.host} -P#{db_admin.port} -e "USE #{db}; SHOW TABLES"
            """
        else throw Error 'Database engine not supported' unless engines[engine]

## Check Port

Check if the Hive HCatalog (Metastore) server is listening.

    module.exports.push name: 'Hive HCatalog # Check Port', label_true: 'CHECKED', handler: ->
      {hive} = @config.ryba
      uris = hive.site['hive.metastore.uris'].split ','
      [server] = for uri in uris
        {hostname, port} = url.parse uri
        continue unless hostname is @config.host
        host: hostname, port: port
      throw Error 'Invalid configuration' unless server
      @execute
        cmd: "echo > /dev/tcp/#{server.host}/#{server.port}"

# Module Dependencies

    url = require 'url'
    parse_jdbc = require '../../lib/parse_jdbc'
