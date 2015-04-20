
# YARN Timeline Server Install

The Timeline Server is a stand-alone server daemon and doesn't need to be
co-located with any other service.

    module.exports = []
    module.exports.push 'masson/bootstrap'
    module.exports.push 'masson/core/krb5_client/wait'
    module.exports.push 'ryba/hadoop/yarn_client'
    module.exports.push require('./index').configure

## IPTables

| Service   | Port       | Proto     | Parameter                                  |
|-----------|------------|-----------|--------------------------------------------|
| timeline  | 10200      | tcp/http  | yarn.timeline-service.address              |
| timeline  | 50075/1006 | tcp/http  | yarn.timeline-service.webapp.address       |
| timeline  | 50475      | tcp/https | yarn.timeline-service.webapp.https.address |

IPTables rules are only inserted if the parameter "iptables.action" is set to 
"start" (default value).

    module.exports.push name: 'YARN TS # IPTables', handler: (ctx, next) ->
      {yarn} = ctx.config.ryba
      [_, rpc_port] = yarn.site['yarn.timeline-service.address'].split ':'
      [_, http_port] = yarn.site['yarn.timeline-service.webapp.address'].split ':'
      [_, https_port] = yarn.site['yarn.timeline-service.webapp.https.address'].split ':'
      ctx.iptables
        rules: [
          { chain: 'INPUT', jump: 'ACCEPT', dport: rpc_port, protocol: 'tcp', state: 'NEW', comment: "Yarn Timeserver RPC" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: http_port, protocol: 'tcp', state: 'NEW', comment: "Yarn Timeserver HTTP" }
          { chain: 'INPUT', jump: 'ACCEPT', dport: https_port, protocol: 'tcp', state: 'NEW', comment: "Yarn Timeserver HTTPS" }
        ]
        if: ctx.config.iptables.action is 'start'
      , next

## Configuration

Update the "yarn-site.xml" configuration file.

    module.exports.push name: 'YARN TS # Configuration', handler: (ctx, next) ->
      return next() unless ctx.hosts_with_module('ryba/hadoop/hdfs_nn').length > 1
      {hadoop_conf_dir, yarn, hadoop_group} = ctx.config.ryba
      ctx.hconfigure
        destination: "#{hadoop_conf_dir}/yarn-site.xml"
        properties: yarn.site
        merge: true
        backup: true
      , next

# Layout

    module.exports.push name: 'YARN TS # Layout', timeout: -1, handler: (ctx, next) ->
      {yarn, hadoop_group} = ctx.config.ryba
      ctx.mkdir
        destination: yarn.site['yarn.timeline-service.leveldb-timeline-store.path']
        uid: yarn.user.name
        gid: hadoop_group.name
        mode: 0o0750
        parent: true
      , next

## Kerberos

Create the Application Timeserver service principal in the form of "ats/{host}@{realm}" and place its
keytab inside "/etc/security/keytabs/ats.service.keytab" with ownerships set to "yarn:yarn"
and permissions set to "0600".

    module.exports.push name: 'HDFS DN # Kerberos', timeout: -1, handler: (ctx, next) ->
      {yarn, realm} = ctx.config.ryba
      {kadmin_principal, kadmin_password, admin_server} = ctx.config.krb5.etc_krb5_conf.realms[realm]
      ctx.krb5_addprinc 
        principal: yarn.site['yarn.timeline-service.principal'].replace '_HOST', ctx.config.host
        randkey: true
        keytab: yarn.site['yarn.timeline-service.keytab']
        uid: yarn.user.name
        gid: yarn.group.name
        mode: 0o0600
        kadmin_principal: kadmin_principal
        kadmin_password: kadmin_password
        kadmin_server: admin_server
      , next
