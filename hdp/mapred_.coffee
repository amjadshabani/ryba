
module.exports = []

module.exports.push module.exports.configure = (ctx) ->
  # Define Users and Groups
  ctx.config.hdp.mapred_user ?= 'mapred'
  ctx.config.hdp.mapred_group ?= 'hadoop'