

# XASecure Policy Manager

    module.exports = []
    module.exports.push 'masson/bootstrap'

    module.exports.push name: 'XASecure Sync # Start', timeout: -1, label_true: 'STARTED', handler: ->
      @service_start
        name: 'uxugsync'
