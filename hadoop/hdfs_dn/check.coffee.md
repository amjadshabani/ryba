
# Hadoop HDFS DataNode Check

Check the DataNode by uploading a file using the HDFS client and the HTTP REST
interface.

Run the command `./bin/ryba check -m ryba/hadoop/hdfs_dn` to check all the
DataNodes.

    module.exports = []
    module.exports.push 'masson/bootstrap'
    module.exports.push 'ryba/hadoop/hdfs_dn/wait'
    module.exports.push 'ryba/hadoop/hdfs_nn/wait'

    module.exports.push (ctx) ->
      require('../core').configure ctx
      require('../core_ssl').configure ctx
      require('../hdfs').configure ctx

## Check Disk Capacity

    module.exports.push name: 'HDFS DN # Check Disk Capacity', timeout: -1, label_true: 'CHECKED', handler: (ctx, next) ->
      {hdfs} = ctx.config.ryba
      protocol = if hdfs.site['dfs.http.policy'] is 'HTTP_ONLY' then 'http' else 'https'
      port = hdfs.site["dfs.datanode.#{protocol}.address"].split(':')[1]
      ctx.execute
        cmd: mkcmd.hdfs ctx, "curl --negotiate -k -u : #{protocol}://#{ctx.config.host}:#{port}/jmx?qry=Hadoop:service=DataNode,name=FSDatasetState-*"
      , (err, executed, stdout) ->
        return next err if err
        try
          data = JSON.parse stdout
          return next Error "Invalid Response" unless /^Hadoop:service=DataNode,name=FSDatasetState-.*/.test data?.beans[0]?.name
          remaining = data.beans[0].Remaining
          total = data.beans[0].Capacity
          ctx.log "Disk remaining: #{Math.round remaining}"
          ctx.log "Disk total: #{Math.round total}"
          percent = (total - remaining)/total * 100;
          return next null, "WARNING: #{Math.round percent}" if percent > 90
          next null, true
        catch err then return next err

## Check HDFS

Attemp to place a file inside HDFS. the file "/etc/passwd" will be placed at
"/user/{test\_user}/#{ctx.config.host}\_dn".

    module.exports.push name: 'HDFS DN # Check HDFS', timeout: -1, label_true: 'CHECKED', label_false: 'SKIPPED', handler: (ctx, next) ->
      {user} = ctx.config.ryba
      ctx.execute
        cmd: mkcmd.test ctx, """
        if hdfs dfs -test -f /user/#{user.name}/#{ctx.config.host}-dn; then exit 2; fi
        echo 'Upload file to HDFS'
        hdfs dfs -put /etc/passwd /user/#{user.name}/#{ctx.config.host}-dn
        """
        code_skipped: 2
      , next

## Test FSCK

Check for various inconsistencies on the overall filesystem. Use the command
`hdfs fsck -list-corruptfileblocks` to list the corrupted blocks.

    module.exports.push name: 'HDFS DN # Check FSCK', label_true: 'CHECKED', timeout: -1, retry: 3, wait: 60000, handler: (ctx, next) ->
      ctx.execute
        cmd: mkcmd.hdfs ctx, "exec 5>&1; hdfs fsck / | tee /dev/fd/5 | tail -1 | grep HEALTHY 1>/dev/null"
      , next

## Check WebHDFS

Check the Kerberos SPNEGO and the Hadoop delegation token. Will only be
executed if the file "/user/{test\_user}/{host}\_webhdfs" generated by this action
is not present on HDFS.

Read [Delegation Tokens in Hadoop Security](http://www.kodkast.com/blogs/hadoop/delegation-tokens-in-hadoop-security)
for more information.

    module.exports.push name: 'HDFS DN # Check WebHDFS', timeout: -1, label_true: 'CHECKED', label_false: 'SKIPPED', handler: (ctx, next) ->
      {hdfs, nameservice, user, force_check, active_nn_host, force_check} = ctx.config.ryba
      is_ha = ctx.hosts_with_module('ryba/hadoop/hdfs_nn').length > 1
      # state = if not is_ha or active_nn_host is ctx.config.host then 'active' else 'standby'
      protocol = if hdfs.site['dfs.http.policy'] is 'HTTP_ONLY' then 'http' else 'https'
      nameservice = if is_ha then ".#{ctx.config.ryba.hdfs.site['dfs.nameservices']}" else ''
      shortname = if is_ha then ".#{ctx.contexts(hosts: active_nn_host)[0].config.shortname}" else ''
      address = hdfs.site["dfs.namenode.#{protocol}-address#{nameservice}#{shortname}"]
      do_init = ->
        ctx.execute
          cmd: mkcmd.test ctx, """
          hdfs dfs -touchz check-#{ctx.config.shortname}-webhdfs
          kdestroy
          """
          code_skipped: 2
          not_if_exec: unless force_check then mkcmd.test ctx, "hdfs dfs -test -f check-#{ctx.config.shortname}-webhdfs"
        , (err, executed, stdout) ->
          return next err if err
          return next null, false unless executed
          do_spnego()
      do_spnego = ->
        ctx.execute
          cmd: mkcmd.test ctx, """
          curl -s --negotiate --insecure -u : "#{protocol}://#{address}/webhdfs/v1/user/#{user.name}?op=LISTSTATUS"
          kdestroy
          """
        , (err, executed, stdout) ->
          return next err if err
          try
            count = JSON.parse(stdout).FileStatuses.FileStatus.filter((e) -> e.pathSuffix is "check-#{ctx.config.shortname}-webhdfs").length
          catch e then return next Error e
          err = Error "Invalid result" unless count
          return next err, false
          do_token()
      do_token = ->
        ctx.execute
          cmd: mkcmd.test ctx, """
          curl -s --negotiate --insecure -u : "#{protocol}://#{address}/webhdfs/v1/?op=GETDELEGATIONTOKEN"
          kdestroy
          """
        , (err, executed, stdout) ->
          return next err if err
          json = JSON.parse(stdout)
          return setTimeout do_tocken, 3000 if json.exception is 'RetriableException'
          token = json.Token.urlString
          ctx.execute
            cmd: """
            curl -s --insecure "#{protocol}://#{address}/webhdfs/v1/user/#{user.name}?delegation=#{token}&op=LISTSTATUS"
            """
          , (err, executed, stdout) ->
            return next err if err
            try
              count = JSON.parse(stdout).FileStatuses.FileStatus.filter((e) -> e.pathSuffix is "check-#{ctx.config.shortname}-webhdfs").length
            catch e then return next Error e
            err = Error "Invalid result" unless count
            return next err, false
            do_end()
      do_end = ->
        next null, true
      do_init()

## Dependencies

    mkcmd = require '../../lib/mkcmd'