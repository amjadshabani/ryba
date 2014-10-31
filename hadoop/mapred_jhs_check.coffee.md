

# Hadoop MapRed JHS Check

    module.exports = []
    module.exports.push 'masson/bootstrap'
    module.exports.push require('./mapred_jhs').configure

## Check HTTP

Check if the JobHistoryServer is started with an HTTP REST command. Once 
started, the server take some time before it can correctly answer HTTP request.
For this reason, the "retry" property is set to the high value of "10".

    module.exports.push name: 'Hadoop MapRed JHS # Check HTTP', retry: 10, callback: (ctx, next) ->
      {test_user, yarn_site, mapred_site} = ctx.config.ryba
      protocol = if yarn_site['yarn.http.policy'] is 'HTTP_ONLY' then 'http' else 'https'
      [host, port] = if protocol is 'http'
      then mapred_site['mapreduce.jobhistory.webapp.address'].split ':'
      else mapred_site['mapreduce.jobhistory.webapp.https.address'].split ':'
      ctx.execute
        cmd: mkcmd.test ctx, """
        curl -s --insecure --negotiate -u : #{protocol}://#{host}:#{port}/ws/v1/history/info
        """
        code_skipped: 2
      , (err, checked, stdout) ->
        return next err if err
        try
          JSON.parse(stdout).historyInfo.hadoopVersion
          return next null, true
        catch err then next err

## Module dependencies

    mkcmd = require '../lib/mkcmd'