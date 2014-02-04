
module.exports = []

module.exports.push (ctx) ->
  require('./core').configure ctx
  ctx.config.hdp.pig_user ?= 'pig'
  ctx.config.hdp.pig_conf_dir ?= '/etc/pig/conf'

###
http://docs.hortonworks.com/HDPDocuments/HDP1/HDP-1.3.1/bk_installing_manually_book/content/rpm-chap5-1.html
###
module.exports.push name: 'HDP Pig # Install', timeout: -1, callback: (ctx, next) ->
  ctx.service
    name: 'pig'
  , (err, serviced) ->
    next err, if serviced then ctx.OK else ctx.PASS

module.exports.push name: 'HDP Pig # Users', callback: (ctx, next) ->
  {hadoop_group} = ctx.config.hdp
  ctx.execute
    cmd: "useradd pig -r -M -g #{hadoop_group} -s /bin/bash -c \"Used by Hadoop Pig service\""
    code: 0
    code_skipped: 9
  , (err, executed) ->
    next err, if executed then ctx.OK else ctx.PASS

module.exports.push name: 'HDP Pig # Configure', callback: (ctx, next) ->
  # Note, HDP default file comes without any config. We
  # could do the same, start with empty config object
  # that user could overwrite
  next null, ctx.PASS

module.exports.push name: 'HDP Pig # Env', callback: (ctx, next) ->
  {hadoop_group, pig_conf_dir, pig_user} = ctx.config.hdp
  ctx.render
    source: "#{__dirname}/files/pig/pig-env.sh"
    destination: "#{pig_conf_dir}/pig-env.sh"
    context: ctx
    local_source: true
    uid: pig_user
    gid: hadoop_group
    mode: 0o755
  , (err, rendered) ->
    next err, if rendered then ctx.OK else ctx.PASS
