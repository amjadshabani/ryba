
exports.hdfs = (ctx, cmd) ->
  {security, hdfs_user, hdfs_password, realm} = ctx.config.hdp
  if security is 'kerberos'
  then "echo #{hdfs_password} | kinit hdfs@#{realm} >/dev/null && {\n#{cmd}\n}"
  else "su -l #{hdfs_user.name} -c \"#{cmd}\""
  # else "kinit -kt /etc/security/keytabs/hdfs.headless.keytab hdfs && {\n#{cmd}\n}"

exports.test = (ctx, cmd) ->
  {security, test_user, test_password, realm} = ctx.config.hdp
  if security is 'kerberos'
  # then "kinit -kt /etc/security/keytabs/test.headless.keytab test && {\n#{cmd}\n}"
  then "echo #{test_password} | kinit #{test_user.name}@#{realm} >/dev/null && {\n#{cmd}\n}"
  else "su -l #{test_user.name} -c \"#{cmd}\""