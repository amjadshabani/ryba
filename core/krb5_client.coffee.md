
    misc = require 'mecano/lib/misc'
    module.exports = []
    module.exports.push 'phyla/core/yum'
    module.exports.push 'phyla/core/ssh'
    module.exports.push 'phyla/core/ntp'
    module.exports.push 'phyla/core/openldap_client'

# Kerberos Client

Kerberos is a network authentication protocol. It is designed 
to provide strong authentication for client/server applications 
by using secret-key cryptography.

This module install the client tools written by the [Massachusetts 
Institute of Technology](http://web.mit.edu).

## Configuration

*   `krb5_client.kadmin_principal` (string, required)
*   `krb5_client.kadmin_password` (string, required)
*   `krb5_client.kadmin_server` (string, required)
*   `krb5_client.realm` (string, required)
*   `krb5_client.etc_krb5_conf` (object)
    Object representing the full ini file in "/etc/krb5.conf". It is
    generated by default.
*   `krb5_client.sshd` (object)
    Properties inserted in the "/etc/ssh/sshd_config" file.

Example:
```json
{
  "krb5_client": {
    "realm": "ADALTAS.COM",
    "kdc": "krb5.hadoop",
    "kadmin_server": "krb5.hadoop",
    "kadmin_principal": "wdavidw/admin@ADALTAS.COM",
    "kadmin_password": "test"
  }
}
```

    module.exports.push module.exports.configure = (ctx) ->
      {realm, kadmin_principal, kadmin_password, kadmin_server} = ctx.config.krb5_client
      throw new Error "Kerberos property kadmin_principal is required" unless kadmin_principal
      throw new Error "Kerberos property kadmin_password is required" unless kadmin_password
      throw new Error "Kerberos property kadmin_server is required" unless kadmin_server
      throw new Error "Kerberos property realm is required" unless realm
      ctx.config.krb5_client.realm = ctx.config.krb5_client.realm.toUpperCase()
      unless ctx.config.krb5_client.etc_krb5_conf
        REALM = ctx.config.krb5_client.realm
        realm = REALM.toLowerCase()
        etc_krb5_conf =
          'logging':
            'default': 'SYSLOG:INFO:LOCAL1'
            'kdc': 'SYSLOG:NOTICE:LOCAL1'
            'admin_server': 'SYSLOG:WARNING:LOCAL1'
          'libdefaults': 
            'default_realm': REALM
            'dns_lookup_realm': false
            'dns_lookup_kdc': false
            'ticket_lifetime': '24h'
            'renew_lifetime': '7d'
            'forwardable': true
          'realms': {}
          'domain_realm': {}
          'appdefaults':
            'pam':
              'debug': false
              'ticket_lifetime': 36000
              'renew_lifetime': 36000
              'forwardable': true
              'krb4_convert': false
        etc_krb5_conf.realms["#{REALM}"] = 
          'kdc': ctx.config.krb5_client.kdc or realm
          'admin_server': ctx.config.krb5_client.kadmin_server or realm
          'default_domain': ctx.config.krb5_client.default_domain or realm
        etc_krb5_conf.domain_realm[".#{realm}"] = REALM
        etc_krb5_conf.domain_realm["#{realm}"] = REALM
        ctx.config.krb5_client.etc_krb5_conf = etc_krb5_conf
      ctx.config.krb5_client.sshd ?= {}
      ctx.config.krb5_client.sshd = misc.merge
        ChallengeResponseAuthentication: 'yes'
        KerberosAuthentication: 'yes'
        KerberosOrLocalPasswd: 'yes'
        KerberosTicketCleanup: 'yes'
        GSSAPIAuthentication: 'yes'
        GSSAPICleanupCredentials: 'yes'
      , ctx.config.krb5_client.sshd

## Install

The package "krb5-workstation" is installed.

    module.exports.push name: 'Krb5 client # Install', timeout: -1, callback: (ctx, next) ->
      ctx.service
        name: 'krb5-workstation'
      , (err, serviced) ->
        next err, if serviced then ctx.OK else ctx.PASS

## Configure

Modify the Kerberos configuration file in "/etc/krb5.conf". Note, 
this action wont be run if the server host a Kerberos server. 
This is to avoid any conflict where both modules would try to write 
their own configuration one. We give the priority to the server module 
which create a Kerberos file with complementary information.

    module.exports.push name: 'Krb5 client # Configure', timeout: -1, callback: (ctx, next) ->
      # Kerberos config is also managed by the kerberos server action.
      ctx.log 'Check who manage /etc/krb5.conf'
      return next null, ctx.INAPPLICABLE if ctx.has_module 'phyla/core/krb5_server'
      {etc_krb5_conf} = ctx.config.krb5_client
      ctx.log 'Update /etc/krb5.conf'
      ctx.ini
        content: etc_krb5_conf
        destination: '/etc/krb5.conf'
        stringify: misc.ini.stringify_square_then_curly
      , (err, written) ->
        return next err, if written then ctx.OK else ctx.PASS

## Host Principal

Create a user principal for this host. The principal is named like "host/{hostname}@{realm}".

    module.exports.push name: 'Krb5 client # Host Principal', timeout: -1, callback: (ctx, next) ->
      {realm, etc_krb5_conf, kadmin_principal, kadmin_password, kadmin_server} = ctx.config.krb5_client
      krb5_admin_servers = for realm, config of etc_krb5_conf.realms then  config.admin_server
      # ctx.waitIsOpen krb5_admin_servers, 88, (err) ->
      ctx.waitForExecution "kadmin -p #{kadmin_principal} -s #{kadmin_server} -w #{kadmin_password} -q 'listprincs'", (err) ->
        return next err if err
        ctx.krb5_addprinc
          principal: "host/#{ctx.config.host}@#{realm}"
          randkey: true
          kadmin_principal: kadmin_principal
          kadmin_password: kadmin_password
          kadmin_server: kadmin_server
        , (err, created) ->
          next err, if created then ctx.OK else ctx.PASS

## Configure SSHD

Updated the "/etc/ssh/sshd\_config" file with properties provided by the "krb5_client.sshd" 
configuration object. By default, we set the following properties to "yes": "ChallengeResponseAuthentication",
"KerberosAuthentication", "KerberosOrLocalPasswd", "KerberosTicketCleanup", "GSSAPIAuthentication", 
"GSSAPICleanupCredentials". The "sshd" service will be restarted if a change to the configuration is detected.

    module.exports.push name: 'Krb5 client # Configure SSHD', timeout: -1, callback: (ctx, next) ->
      {sshd} = ctx.config.krb5_client
      return next null, ctx.DISABLED unless sshd
      write = for k, v of sshd
        match: new RegExp "^#{k}.*$", 'mg'
        replace: "#{k} #{v}"
        append: true
      ctx.log 'Write /etc/ssh/sshd_config'
      ctx.write
        write: write
        destination: '/etc/ssh/sshd_config'
      , (err, written) ->
        return next err if err
        return next null, ctx.PASS unless written
        ctx.log 'Restart openssh'
        ctx.service
          name: 'openssh'
          srv_name: 'sshd'
          action: 'restart'
        , (err, restarted) ->
          next err, ctx.OK

## Usefull client commands

*   List all the current principals in the realm: `getprincs`
*   Login to a local kadmin: `kadmin.local`
*   Login to a remote kadmin: `kadmin -p wdavidw/admin@ADALTAS.COM -s krb5.hadoop`
*   Print details on a principal: `getprinc host/hadoop1.hadoop@ADALTAS.COM`
*   Examine the content of the /etc/krb5.keytab: `klist -etk /etc/krb5.keytab`
*   Destroy our own tickets: `kdestroy`
*   Get a user ticket: `kinit -p wdavidw@ADALTAS.COM`
*   Confirm that we do indeed have the new ticket: `klist`
*   Check krb5kdc is listening: `netstat -nap | grep :750` and `netstat -nap | grep :88`

## Todo

*   Enable sshd(8) Kerberos authentication.
*   Enable PAM Kerberos authentication.
*   SASL GSSAPI OpenLDAP authentication.
*   Use SASL GSSAPI Authentication with AutoFS.

## Notes

Kerberos clients require connectivity to the KDC's TCP ports 88 and 749.

Renewable tickets is per default disallowed in the most linux distributions. This can be done per:

```bash
kadmin.local: modprinc -maxrenewlife 7day krbtgt/YOUR_REALM
kadmin.local: modprinc -maxrenewlife 7day +allow_renewable hue/FQRN
```
