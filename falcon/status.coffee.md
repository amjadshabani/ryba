
# Falcon Status

Run the command `su -l falcon -c '/usr/lib/falcon/bin/falcon-status'` to
retrieve the status of the Falcon server using Ryba.

    module.exports = []
    module.exports.push 'masson/bootstrap'
    module.exports.push require('./index').configure

## Status Service

Discover the server status.

    module.exports.push name: 'Falcon # Status Service', timeout: -1, label_true: 'STARTED', label_false: 'STOPPED', callback: (ctx, next) ->
      {user} = ctx.config.ryba.falcon
      ctx.execute
        cmd: "su -l #{user.name} -c '/usr/lib/falcon/bin/falcon-status'"
        code: 254
        code_skipped: 255
        if_exists: '/usr/lib/falcon/bin/falcon-status'
      , next