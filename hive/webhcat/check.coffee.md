
# WebHCat Check

    module.exports = []
    module.exports.push 'masson/bootstrap/'
    module.exports.push require('./index').configure

    module.exports.push name: 'WebHCat # Check Status', label_true: 'CHECKED', handler: (ctx, next) ->
      # TODO, maybe we could test hive:
      # curl --negotiate -u : -d execute="show+databases;" -d statusdir="test_webhcat" http://front1.hadoop:50111/templeton/v1/hive
      {webhcat} = ctx.config.ryba
      port = webhcat.site['templeton.port']
      ctx.execute
        cmd: mkcmd.test ctx, """
        if hdfs dfs -test -f #{ctx.config.host}-webhcat; then exit 2; fi
        curl -s --negotiate -u : http://#{ctx.config.host}:#{port}/templeton/v1/status
        hdfs dfs -touchz #{ctx.config.host}-webhcat
        """
        code_skipped: 2
      , (err, executed, stdout) ->
        return next err if err
        return next null, false unless executed
        return next new Error "WebHCat not started" if stdout.trim() isnt '{"status":"ok","version":"v1"}'
        return next null, true

# Dependencies

    mkcmd = require '../../lib/mkcmd'