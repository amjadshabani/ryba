
# Rexster Stop

Run the command `./bin/ryba stop -m ryba/titan/rexster` to stop the Rexster
server using Ryba.

    module.exports = []
    module.exports.push 'masson/bootstrap'
    # module.exports.push require('./').configure

## Stop

Stop the Rexster server. You can also stop the server manually with the
following command:

```
ps aux | grep "rexster"
kill ...
```

    module.exports.push name: 'Rexster # Stop', label_true: 'STOPPED', handler: ->
      {titan, rexster} = @config.ryba
      @execute
        cmd: """
        p=`ps aux | grep "com.tinkerpop.rexster.Application" | grep -v grep`
        if [ -z "$p" ]; then exit 3; fi
        #{path.join titan.home, 'bin', 'rexster.sh'} --stop --wait -rp #{rexster.config['shutdown-port']} | grep 'Rexster Server shutdown complete'
        """
        code_skipped: 3
        if_exists: '/opt/titan/current/bin/rexster.sh'

## Stop Clean Logs

    module.exports.push name: 'Rexster # Stop Clean Logs', label_true: 'CLEANED', handler: ->
      {rexster, clean_logs} = @config.ryba
      @execute
        cmd: "rm #{rexster.log_dir}/*"
        code_skipped: 1
        if: clean_logs

## Dependencies

    path = require 'path'
