
# Hive HCatalog Status

    module.exports = []
    module.exports.push 'masson/bootstrap'

## Status

Check if the HCatalog is running. The process ID is located by default
inside "/var/lib/hive-hcatalog/hcat.pid".

    module.exports.push name: 'Hive HCatalog # Status', label_true: 'STARTED', label_false: 'STOPPED', handler: ->
      @execute
        cmd: 'service hive-hcatalog-server status'
        code_skipped: 3
        if_exists: '/etc/init.d/hive-hcatalog-server'
