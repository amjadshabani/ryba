
# Hadoop HDFS NameNode Backup

comprendre les proprietes de sauvegarde des 2 fsimages et trouver la proprietes du laps de temps entre 2 creations.

## HDFS cli

### OIV

can dump content of HDFS fsimages

Use `hdfs oiv` (can run offline)
hdfs oiv -p FileDistribution -i /var/hdfs/name/current/fsimage_0000000000000023497 -o test_fd
hdfs oiv -p Ls -i /var/hdfs/name/current/fsimage_0000000000000023497 -o test_ls

### OEV

can load content of HDFS fsimages dump

## Curl

Use `curl` to download image and edit logs:
https://<namenode>:50470/getimage?getimage=1&txid=latest
https://<namenode>:50470/getimage?getedit=1&startTxId=X&endTxId=Y

dfsadmin -fetchImage

## Node-backmeup

### Local Backup

    module.exports = []

    module.exports.push 'masson/bootstrap'
    module.exports.push 'masson/bootstrap/utils'
    # module.exports.push require('./index').configure

    # isRelative = () ->
    #   filepath = path.join.apply path, arguments
    #   return path.resolve(filepath) isnt filepath.replace(/[\/\\]+$/, ''\

    module.exports.push name: "HDFS NN # Backup HDFS LS output", timeout: -1, label_true: 'BACKUPED', handler: ->
      @backup
        name: 'ls'
        cmd: 'hdfs dfs -ls -R / '
        destination: "/var/backups/nn_#{@config.host}/"
        interval: month: 1
        retention: count: 2

    module.exports.push name: 'HDFS NN # Backup FSimages & edits', timeout: -1, label_true: 'BACKUPED', handler: ->
      {hdfs} = @config.ryba
      any_dfs_name_dir = hdfs.site['dfs.namenode.name.dir'].split(',')[0]
      any_dfs_name_dir = any_dfs_name_dir.substr(7) if any_dfs_name_dir.indexOf('file://') is 0
      @backup
        name: 'fs'
        source: path.join any_dfs_name_dir, 'current'
        filter: ['fsimage_*','edits_0*']
        destination: "/var/backups/nn_#{@config.host}/"
        interval: month: 1
        retention: count: 2

### Restoration procedure

To restore the fsimage as it was at the date of backup with a shell command
with default configuration value:
```bash
cd /var/hdfs/name/current/
rm -rf *
tar -xzf /var/backups/nn_$HOSTNAME/<backup_date>.tar.gz
```

`man tar` for more information if you have changed default options

## Dependencies

    util = require 'util'
    path = require 'path'
