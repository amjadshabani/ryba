
# Zookeeper Server Wait

    module.exports = []
    module.exports.push 'masson/bootstrap'
    # module.exports.push require('./index').configure

## Wait Listen

Wait for all ZooKeeper server to listen.

    module.exports.push name: 'ZooKeeper Server # Wait Listen', timeout: -1, label_true: 'READY', handler: ->
      @wait_connect
        servers: for zk_ctx in @contexts 'ryba/zookeeper/server'
          host: zk_ctx.config.host, port: zk_ctx.config.ryba.zookeeper.port
        quorum: true
