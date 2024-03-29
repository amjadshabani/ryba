
# Hadoop HDFS SecondaryNameNode Install

    module.exports = []
    module.exports.push 'masson/bootstrap'
    module.exports.push 'ryba/hadoop/hdfs'
    # module.exports.push require('./index').configure
    module.exports.push require '../../lib/hconfigure'
    module.exports.push require '../../lib/hdp_select'

## IPTables

| Service    | Port | Proto  | Parameter                  |
|------------|------|--------|----------------------------|
| namenode  | 50070 | tcp    | dfs.namdnode.http-address  |
| namenode  | 50470 | tcp    | dfs.namenode.https-address |
| namenode  | 8020  | tcp    | fs.defaultFS               |
| namenode  | 8019  | tcp    | dfs.ha.zkfc.port           |

IPTables rules are only inserted if the parameter "iptables.action" is set to
"start" (default value).

    module.exports.push name: 'HDFS SNN # IPTables', handler: ->
      {hdfs} = @config.ryba
      [_, http_port] = hdfs.site['dfs.namenode.secondary.http-address'].split ':'
      [_, https_port] = hdfs.site['dfs.namenode.secondary.https-address'].split ':'
      @iptables
        rules: [
          { chain: 'INPUT', jump: 'ACCEPT', dport: http_port, protocol: 'tcp', state: 'NEW', comment: "HDFS SNN HTTP" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: https_port, protocol: 'tcp', state: 'NEW', comment: "HDFS SNN HTTPS" }
        ]
        if: @config.iptables.action is 'start'

## Service

Install the "hadoop-hdfs-secondarynamenode" service, symlink the rc.d startup
script inside "/etc/init.d" and activate it on startup.

    module.exports.push name: 'HDFS SNN # Service', handler: ->
      @service
        name: 'hadoop-hdfs-secondarynamenode'
      @hdp_select
        name: 'hadoop-hdfs-client' # Not checked
        name: 'hadoop-hdfs-secondarynamenode'
      @write
        source: "#{__dirname}/../resources/secondarynamenode"
        local_source: true
        destination: '/etc/init.d/hadoop-hdfs-secondarynamenode'
        mode: 0o0755
        unlink: true
      @execute
        cmd: "service hadoop-hdfs-secondarynamenode restart"
        if: -> @status -3

    module.exports.push name: 'HDFS SNN # Directories', timeout: -1, handler: ->
      {hdfs, hadoop_group} = @config.ryba
      @log? "Create SNN data, checkpind and pid directories"
      pid_dir = hdfs.pid_dir.replace '$USER', hdfs.user.name
      @mkdir
        destination: for dir in hdfs.site['dfs.namenode.checkpoint.dir'].split ','
          if dir.indexOf('file://') is 0
          then dir.substr(7) else dir
        uid: hdfs.user.name
        gid: hadoop_group.name
        mode: 0o755
      @mkdir
        destination: "#{pid_dir}"
        uid: hdfs.user.name
        gid: hadoop_group.name
        mode: 0o755

    module.exports.push name: 'HDFS SNN # Kerberos', handler: ->
      {realm, hdfs} = @config.ryba
      {kadmin_principal, kadmin_password, admin_server} = @config.krb5.etc_krb5_conf.realms[realm]
      @krb5_addprinc
        principal: "nn/#{@config.host}@#{realm}"
        randkey: true
        keytab: hdfs.site['dfs.secondary.namenode.keytab.file']
        uid: 'hdfs'
        gid: 'hadoop'
        kadmin_principal: kadmin_principal
        kadmin_password: kadmin_password
        kadmin_server: admin_server

# Configure

    module.exports.push name: 'HDFS SNN # Configure', handler: ->
      {hdfs, hadoop_conf_dir, hadoop_group} = @config.ryba
      @hconfigure
        destination: "#{hadoop_conf_dir}/hdfs-site.xml"
        default: "#{__dirname}/../../resources/core_hadoop/hdfs-site.xml"
        local_default: true
        properties: hdfs.site
        uid: hdfs.user
        gid: hadoop_group
        merge: true
        backup: true
