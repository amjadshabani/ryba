
url = require 'url'
path = require 'path'
misc = require 'mecano/lib/misc'
each = require 'each'
hconfigure = require './lib/hconfigure'

module.exports = []
module.exports.push 'histi/actions/yum'
module.exports.push 'histi/actions/krb5_client' #kadmin must be present

###

Kerberos
--------

See official [Running Hadoop in Secure Mode](http://hadoop.apache.org/docs/r2.1.0-beta/hadoop-project-dist/hadoop-common/ClusterSetup.html#Running_Hadoop_in_Secure_Mode).

dn.service.keytab
  dn/full.qualified.domain.name@REALM.TLD
  host/full.qualified.domain.name@REALM.TLD

nn.service.keytab
  nn/full.qualified.domain.name@REALM.TLD
  host/full.qualified.domain.name@REALM.TLD

sn.service.keytab
  sn/full.qualified.domain.name@REALM.TLD
  host/full.qualified.domain.name@REALM.TLD
  
rm.service.keytab
  rm/full.qualified.domain.name@REALM.TLD
  host/full.qualified.domain.name@REALM.TLD

nm.service.keytab
  nm/full.qualified.domain.name@REALM.TLD
  host/full.qualified.domain.name@REALM.TLD

jhs.service.keytab
  jhs/full.qualified.domain.name@REALM.TLD
  host/full.qualified.domain.name@REALM.TLD
###
module.exports.push module.exports.configure = (ctx) ->
  require('../actions/proxy').configure ctx
  ctx.config.hdp ?= {}
  ctx.config.hdp.format ?= false
  ctx.config.hdp.hadoop_conf_dir ?= '/etc/hadoop/conf'
  # Repository
  ctx.config.hdp.proxy = ctx.config.proxy.http_proxy if typeof ctx.config.hdp.http_proxy is 'undefined'
  ctx.config.hdp.hdp_repo ?= 'http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/2.0.6.0/hdp.repo'
  # Define the role
  ctx.config.hdp.namenode ?= false
  ctx.config.hdp.secondary_namenode ?= false
  ctx.config.hdp.datanode ?= false
  ctx.config.hdp.hbase_master ?= false
  # ctx.config.hdp.hbase_regionserver ?= false
  ctx.config.hdp.zookeeper ?= false
  ctx.config.hdp.hcatalog_server ?= false
  ctx.config.hdp.oozie ?= false
  ctx.config.hdp.webhcat ?= false
  # Define Users and Groups
  ctx.config.hdp.hadoop_user ?= 'root'
  ctx.config.hdp.hadoop_group ?= 'hadoop'
  # Define Directories for Ecosystem Components
  ctx.config.hdp.sqoop_conf_dir ?= '/etc/sqoop/conf'
  # Options and configuration
  ctx.config.hdp.core ?= {}
  ctx.hconfigure = (options, callback) ->
    options.ssh = ctx.ssh if typeof options.ssh is 'undefined'
    options.log ?= ctx.log
    hconfigure options, callback

###
Repository
----------
Declare the HDP repository.
###
module.exports.push name: 'HDP Core # Repository', timeout: -1, callback: (ctx, next) ->
  {proxy, hdp_repo} = ctx.config.hdp
  # Is there a repo to download and install
  return next() unless hdp_repo
  modified = false
  do_repo = ->
    ctx.log "Download #{hdp_repo} to /etc/yum.repos.d/hdp.repo"
    u = url.parse hdp_repo
    ctx[if u.protocol is 'http:' then 'download' else 'upload']
      source: hdp_repo
      destination: '/etc/yum.repos.d/hdp.repo'
      proxy: proxy
    , (err, downloaded) ->
      return next err if err
      return next null, ctx.PASS unless downloaded
      do_update()
  do_update = ->
      ctx.log 'Clean up metadata and update'
      ctx.execute
        cmd: "yum clean metadata; yum update -y"
      , (err, executed) ->
        # next err, ctx.OK
        return next err if err
        do_keys()
  do_keys = ->
    ctx.log 'Upload PGP keys'
    misc.file.readFile ctx.ssh, "/etc/yum.repos.d/hdp.repo", (err, content) ->
      return next err if err
      keys = {}
      reg = /^pgkey=(.*)/gm
      while matches = reg.exec content
        keys[matches[1]] = true
      keys = Object.keys keys
      return next() unless keys.length
      each(keys)
      .on 'item', (key, next) ->
        ctx.execute
          cmd: """
          curl #{key} -o /etc/pki/rpm-gpg/#{path.basename key}
          rpm --import  /etc/pki/rpm-gpg/#{path.basename key}
          """
        , (err, executed) ->
          next err
      .on 'both', (err) ->
        next err, ctx.OK
  do_repo()

#http://docs.hortonworks.com/HDPDocuments/HDP1/HDP-1.2.3.1/bk_installing_manually_book/content/rpm-chap1-9.html
#http://hadoop.apache.org/docs/current/hadoop-project-dist/hadoop-common/ClusterSetup.html#Running_Hadoop_in_Secure_Mode
module.exports.push name: 'HDP Core # Users & Groups', callback: (ctx, next) ->
  cmds = []
  {hadoop_group} = ctx.config.hdp
  ctx.execute
    cmd: "groupadd hadoop"
    code: 0
    code_skipped: 9
  , (err, executed) ->
    next err, if executed then ctx.OK else ctx.PASS

module.exports.push name: 'HDP Core # Install', timeout: -1, callback: (ctx, next) ->
  ctx.service [
  # wdavidw:
  # Installing the "hadoop" package as documented
  # generates "No package hadoop available", 
  # maybe because we cannot install directly this package
    name: 'openssl'
  ,
    name: 'hadoop-client'
  ], (err, serviced) ->
    next err, if serviced then ctx.OK else ctx.PASS

module.exports.push name: 'HDP Core # Configuration', callback: (ctx, next) ->
  namenode = ctx.hosts_with_module 'histi/hdp/hdfs_nn', 1
  ctx.log "Namenode: #{namenode}"
  { core, hadoop_conf_dir } = ctx.config.hdp
  modified = false
  do_core = ->
    ctx.log 'Configure core-site.xml'
    # NameNode hostname
    core['fs.defaultFS'] ?= "hdfs://#{namenode}:8020"
    # Determines where on the local filesystem the DFS secondary
    # name node should store the temporary images to merge.
    # If this is a comma-delimited list of directories then the image is
    # replicated in all of the directories for redundancy.
    # core['fs.checkpoint.edits.dir'] ?= fs_checkpoint_edit_dir.join ','
    # A comma separated list of paths. Use the list of directories from $FS_CHECKPOINT_DIR. 
    # For example, /grid/hadoop/hdfs/snn,sbr/grid1/hadoop/hdfs/snn,sbr/grid2/hadoop/hdfs/snn
    # core['fs.checkpoint.dir'] ?= fs_checkpoint_dir.join ','
    ctx.hconfigure
      destination: "#{hadoop_conf_dir}/core-site.xml"
      default: "#{__dirname}/files/core_hadoop/core-site.xml"
      local_default: true
      properties: core
      merge: true
    , (err, configured) ->
      return next err if err
      modified = true if configured
      do_end()
  do_end = ->
    next null, if modified then ctx.OK else ctx.PASS
  do_core()

module.exports.push name: 'HDP Core # Environnment', timeout: -1, callback: (ctx, next) ->
  ctx.write
    destination: '/etc/profile.d/hadoop.sh'
    content: """
    #!/bin/bash
    export HADOOP_HOME=/usr/lib/hadoop
    """
    mode: '644'
  , (err, written) ->
    next null, if written then ctx.OK else ctx.PASS

module.exports.push name: 'HDP Core # Compression', timeout: -1, callback: (ctx, next) ->
  modified = false
  { hadoop_conf_dir } = ctx.config.hdp
  do_snappy = ->
    ctx.service [
      name: 'snappy'
    ,
      name: 'snappy-devel'
    ], (err, serviced) ->
      return next err if err
      return do_lzo() unless serviced
      ctx.execute
        cmd: 'ln -sf /usr/lib64/libsnappy.so /usr/lib/hadoop/lib/native/.'
      , (err, executed) ->
        return next err if err
        modified = true
        do_lzo()
  do_lzo = ->
    ctx.service [
      name: 'lzo'
    ,
      name: 'lzo-devel'
    ,
      name: 'hadoop-lzo'
    ,
      name: 'hadoop-lzo-native'
    ], (err, serviced) ->
      return next err if err
      modified = true if serviced
      do_core()
  do_core = ->
    ctx.log 'Configure core-site.xml'
    core = {}
    core['io.compression.codecs'] ?= "org.apache.hadoop.io.compress.GzipCodec,org.apache.hadoop.io.compress.DefaultCodec,org.apache.hadoop.io.compress.SnappyCodec"
    ctx.hconfigure
      destination: "#{hadoop_conf_dir}/core-site.xml"
      properties: core
      merge: true
    , (err, configured) ->
      return next err if err
      modified = true if configured
      do_end()
  do_end = ->
    next null, if modified then ctx.OK else ctx.PASS
  do_snappy()

module.exports.push name: 'HDP Core # Kerberos', timeout: -1, callback: (ctx, next) ->
  {realm} = ctx.config.krb5_client
  {hadoop_conf_dir} = ctx.config.hdp
  core = {}
  # Set the authentication for the cluster. Valid values are: simple or kerberos
  core['hadoop.security.authentication'] ?= 'kerberos'
  # This is an [OPTIONAL] setting. If not set, defaults to 
  # authentication.authentication= authentication only; the client and server 
  # mutually authenticate during connection setup.integrity = authentication 
  # and integrity; guarantees the integrity of data exchanged between client 
  # and server aswell as authentication.privacy = authentication, integrity, 
  # and confidentiality; guarantees that data exchanged between client andserver 
  # is encrypted and is not readable by a “man in the middle”.
  core['hadoop.rpc.protection'] ?= 'authentication'
  # Enable authorization for different protocols.
  core['hadoop.security.authorization'] ?= 'true'
  # The mapping from Kerberos principal names to local OS user names.
  # core['hadoop.security.auth_to_local'] ?= """
  #   RULE:[2:$1@$0]([jt]t@.*#{realm})s/.*/mapred/
  #   RULE:[2:$1@$0]([nd]n@.*#{realm})s/.*/hdfs/
  #   DEFAULT
  #   """
  # Forgot where I find this one, but referenced here: http://mail-archives.apache.org/mod_mbox/incubator-ambari-commits/201308.mbox/%3Cc82889130fc54e1e8aeabfeedf99dcb3@git.apache.org%3E
  core['hadoop.security.auth_to_local'] ?= """
  
        RULE:[2:$1@$0]([rn]m@.*)s/.*/yarn/
        RULE:[2:$1@$0](jhs@.*)s/.*/mapred/
        RULE:[2:$1@$0]([nd]n@.*)s/.*/hdfs/
        RULE:[2:$1@$0](hm@.*)s/.*/hbase/
        RULE:[2:$1@$0](rs@.*)s/.*/hbase/
        DEFAULT
    """
  # Allow the superuser hive to impersonate any members of the group users. Required only when installing Hive.
  core['hadoop.proxyuser.hive.groups'] ?= '*'
  # Hostname from where superuser hive can connect. Required 
  # only when installing Hive.
  core['hadoop.proxyuser.hive.hosts'] ?= '*'
  # Allow the superuser oozie to impersonate any members of 
  # the group users. Required only when installing Oozie.
  core['hadoop.proxyuser.oozie.groups'] ?= '*'
  # Hostname from where superuser oozie can connect. Required 
  # only when installing Oozie.
  core['hadoop.proxyuser.oozie.hosts'] ?= '*'
  # Hostname from where superuser hcat can connect. Required 
  # only when installing WebHCat.
  core['hadoop.proxyuser.hcat.hosts'] ?= '*'
  # Hostname from where superuser HTTP can connect.
  core['hadoop.proxyuser.HTTP.groups'] ?= '*'
  # Allow the superuser hcat to impersonate any members of the 
  # group users. Required only when installing WebHCat.
  core['hadoop.proxyuser.hcat.groups'] ?= '*'
  # Hostname from where superuser hcat can connect. This is 
  # required only when installing webhcat on the cluster.
  core['hadoop.proxyuser.hcat.hosts'] ?= '*'
  core['hadoop.proxyuser.hue.groups'] ?= '*'
  core['hadoop.proxyuser.hue.hosts'] ?= '*'
  ctx.hconfigure
    destination: "#{hadoop_conf_dir}/core-site.xml"
    properties: core
    merge: true
  , (err, configured) ->
    next err, if configured then ctx.OK else ctx.PASS

###
Configure Web
-------------

This action follow the ["Authentication for Hadoop HTTP web-consoles" 
recommandations](http://hadoop.apache.org/docs/r1.2.1/HttpAuthentication.html).
###
module.exports.push  name: 'HDP Core # Kerberos Web UI', callback:(ctx, next) ->
  {krb5_client, realm} = ctx.config.krb5_client
  namenode = ctx.hosts_with_module 'histi/hdp/hdfs_nn', 1
  ctx.execute
    cmd: 'dd if=/dev/urandom of=/etc/hadoop/hadoop-http-auth-signature-secret bs=1024 count=1'
    not_if_exists: '/etc/hadoop/hadoop-http-auth-signature-secret'
  , (err, executed) ->
    return next err if err
    ctx.hconfigure
      destination: '/etc/hadoop/conf/core-site.xml'
      properties:
        'hadoop.http.filter.initializers': 'org.apache.hadoop.security.AuthenticationFilterInitializer'
        'hadoop.http.authentication.type': 'kerberos'
        'hadoop.http.authentication.token.validity': 36000
        'hadoop.http.authentication.signature.secret.file': '/etc/hadoop/hadoop-http-auth-signature-secret'
        'hadoop.http.authentication.cookie.domain': namenode
        'hadoop.http.authentication.simple.anonymous.allowed': 'false'
        # For some reason, _HOST isnt leveraged
        'hadoop.http.authentication.kerberos.principal': "HTTP/#{ctx.config.host}@#{realm}"
        'hadoop.http.authentication.kerberos.keytab': '/etc/security/keytabs/spnego.service.keytab'
      merge: true
    , (err, configured) ->
      next err, if configured then ctx.OK else ctx.PASS


    









