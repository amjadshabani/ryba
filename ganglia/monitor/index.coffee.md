
# Ganglia Monitor

[Ganglia](http://ganglia.sourceforge.net) is a scalable distributed monitoring system for high-performance computing systems such as clusters and Grids.
 It is based on a hierarchical design targeted at federations of clusters.
Ganglia Monitor is the agent to be deployed on each of the hosts.

    module.exports = []

## Commands

    # module.exports.push command: 'backup', modules: 'ryba/ganglia/monitor/backup'

    # module.exports.push commands: 'check', modules: 'ryba/ganglia/monitor/check'

    module.exports.push commands: 'install', modules: [
      'ryba/ganglia/monitor/install'
      'ryba/ganglia/monitor/start'
    ]

    module.exports.push commands: 'start', modules: 'ryba/ganglia/monitor/start'

    # module.exports.push commands: 'status', modules: 'ryba/ganglia/monitor/status'

    module.exports.push commands: 'stop', modules: 'ryba/ganglia/monitor/stop'
