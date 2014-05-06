---
title: Pig
module: phyla/hadoop/pig
layout: module
---

# Pig

Apache Pig is a platform for analyzing large data sets that consists of a 
high-level language for expressing data analysis programs, coupled with 
infrastructure for evaluating these programs. The salient property of Pig 
programs is that their structure is amenable to substantial parallelization, 
which in turns enables them to handle very large data sets. 

    mkcmd = require './lib/mkcmd'
    module.exports = []
    module.exports.push 'masson/bootstrap/'
    module.exports.push 'masson/bootstrap/utils'
    module.exports.push 'phyla/hadoop/mapred_client'
    module.exports.push 'phyla/hadoop/yarn_client'

## Configuration

Pig uses the "hdfs" configuration. It also declare 2 optional properties:

*   `hdp.force_check` (string)   
    Force the execution of the check action on each run, otherwise it will
    run only on the first install. The property is shared by multiple
    modules and default to false.   
*   `hdp.pig_user` (string)   
    The Pig user, dont overwrite, default to "pig".   
*   `hdp.pig_conf_dir` (string)   
    The Pig configuration directory, dont overwrite, default to "/etc/pig/conf".   

Example:

```json
{
  "hdp": {
    force_check: true
  }
}
```

    module.exports.push module.exports.configure = (ctx) ->
      require('./hdfs').configure ctx
      ctx.config.hdp.pig_user ?= 'pig'
      ctx.config.hdp.pig_conf_dir ?= '/etc/pig/conf'

## Install

The pig package is install.

    module.exports.push name: 'HDP Pig # Install', timeout: -1, callback: (ctx, next) ->
      ctx.service
        name: 'pig'
      , (err, serviced) ->
        next err, if serviced then ctx.OK else ctx.PASS

    module.exports.push name: 'HDP Pig # Users', callback: (ctx, next) ->
      # 6th feb 2014: pig user isnt created by YUM, might change in a future HDP release
      {hadoop_group} = ctx.config.hdp
      ctx.execute
        cmd: "useradd pig -r -M -g #{hadoop_group} -s /bin/bash -c \"Used by Hadoop Pig service\""
        code: 0
        code_skipped: 9
      , (err, executed) ->
        next err, if executed then ctx.OK else ctx.PASS

## Configure

TODO: Generate the "pig.properties" file dynamically, be carefull, the HDP
companion file define no properties while the YUM package does.

    module.exports.push name: 'HDP Pig # Configure', callback: (ctx, next) ->
      next null, ctx.PASS

    module.exports.push name: 'HDP Pig # Env', callback: (ctx, next) ->
      {hadoop_group, pig_conf_dir, pig_user} = ctx.config.hdp
      ctx.write
        source: "#{__dirname}/files/pig/pig-env.sh"
        destination: "#{pig_conf_dir}/pig-env.sh"
        local_source: true
        uid: pig_user
        gid: hadoop_group
        mode: 0o755
        backup: true
      , (err, rendered) ->
        next err, if rendered then ctx.OK else ctx.PASS

## Check

Run a Pig script to test the installation once the ResourceManager is 
installed. The script will only be executed the first time it is deployed 
unless the "hdp.force_check" configuration property is set to "true".

    module.exports.push name: 'HDP Pig # Check', callback: (ctx, next) ->
      {force_check} = ctx.config.hdp
      rm = ctx.host_with_module 'phyla/hadoop/yarn_rm'
      ctx.waitIsOpen rm, 8050, (err) ->
        return next err if err
        ctx.execute
          cmd: mkcmd.test ctx, """
          if hdfs dfs -test -d /user/test/#{ctx.config.host}-pig; then exit 1; fi
          exit 0
          """
          code: 1
          code_skipped: 0
          not_if: force_check
        , (err, skip) ->
          return next err, ctx.PASS if err or skip
          ctx.execute
            cmd: mkcmd.test ctx, """
            hdfs dfs -rm -r /user/test/#{ctx.config.host}-pig
            hdfs dfs -mkdir -p /user/test/#{ctx.config.host}-pig
            echo -e 'a|1\\\\nb|2\\\\nc|3' | hdfs dfs -put - /user/test/#{ctx.config.host}-pig/data
            """
          , (err, executed) ->
            return next err if err
            ctx.write
              content: """
              data = LOAD '/user/test/#{ctx.config.host}-pig/data' USING PigStorage(',') AS (text, number);
              result = foreach data generate UPPER(text), number+2;
              STORE result INTO '/user/test/#{ctx.config.host}-pig/result' USING PigStorage();
              """
              destination: '/home/test/test.pig'
            , (err, written) ->
              return next err if err
              ctx.execute
                cmd: mkcmd.test ctx, """
                pig /home/test/test.pig
                rm -rf /home/test/test.pig
                hdfs dfs -test -d /user/test/#{ctx.config.host}-pig/result
                """
              , (err, executed) ->
                next err, ctx.OK




