
exports.hbase = (ctx, cmd) ->
  {security, hbase, realm} = ctx.config.ryba
  if security is 'kerberos'
  then "echo '#{hbase.admin.password}' | kinit #{hbase.admin.principal} >/dev/null && {\n#{cmd}\n}"
  else "su -l #{hbase.user.name} -c \"#{cmd}\""
  # else "kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs && {\n#{cmd}\n}"

exports.hdfs = (ctx, cmd) ->
  {security, hdfs, realm} = ctx.config.ryba
  if security is 'kerberos'
  then "echo '#{hdfs.krb5_user.password}' | kinit #{hdfs.krb5_user.principal} >/dev/null && {\n#{cmd}\n}"
  else "su -l #{hdfs.user.name} -c \"#{cmd}\""
  # else "kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs && {\n#{cmd}\n}"

exports.test = (ctx, cmd) ->
  {security, user, krb5_user, realm} = ctx.config.ryba
  if security is 'kerberos'
  # then "kinit -kt /etc/security/keytabs/test.headless.keytab test && {\n#{cmd}\n}"
  then "echo #{krb5_user.password} | kinit #{krb5_user.name}@#{realm} >/dev/null && {\n#{cmd}\n}"
  else "su -l #{user.name} -c \"#{cmd}\""
