
# Network

Modify the various network related configuration files such as
"/etc/hosts" and "/etc/resolv.conf".

    misc = require 'mecano/lib/misc'
    network = module.exports = []

# Configuration

The module accept the following properties:

*   `network.auto_hosts` (boolean)   
    Enrich the "/etc/hosts" file with the server hostname present on the cluster, default to false   
*   `network.hosts` (object)   
    Enrich the "/etc/hosts" file with custom adresses, the keys represent the IPs and the value the hostnames, optional.   
*   `network.resolv` (string)   
    Content of the '/etc/resolv.conf' file, optional.

Example:

```json
{
  "auto_hosts": true,
  "hosts": {
    "10.10.10.15": "myserver.hadoop"
  },
  "resolv": "search hadoop\nnameserver 10.10.10.16\nnameserver 10.0.2.3"
}
```

    network.push (ctx) ->
      ctx.config.network ?= {}
      ctx.config.network.auto_hosts ?= false

## Network # Hosts

Ovewrite the "/etc/hosts" file with the hostname resolution defined 
by the property "network.hosts". This configuration may be automatically
enriched with the cluster hostname if the property "network.auto_hosts" is
set.

    network.push name: 'Network # Hosts', callback: (ctx, next) ->
      {hosts, auto_hosts} = ctx.config.network
      content = ''
      if auto_hosts then for server in ctx.config.servers
        content += "#{server.ip} #{server.host}\n"
      for ip, hostnames of hosts
        content += "#{ip} #{hostnames}\n"
      ctx.write
        destination: '/etc/hosts'
        content: content
        mode: 0o666
        backup: true
      , (err, written) ->
        return next err, if written then ctx.OK else ctx.PASS

## Network # Hostname

Declare the server hostname. On CentOs like system, the 
relevant file is "/etc/sysconfig/network".

    network.push name: 'Network # Hostname', callback: (ctx, next) ->
      ctx.write
        match: /^HOSTNAME=.*/mg
        replace: "HOSTNAME=#{ctx.config.host}"
        destination: '/etc/sysconfig/network'
      , (err, replaced) ->
        return next err if err
        return next null, ctx.PASS unless replaced 
        ctx.execute
          cmd: "hostname #{ctx.config.host} && service network restart"
        , (err, executed) ->
          next err, ctx.OK

## Network # DNS resolv

Write the DNS configuration. On CentOs like system, this is configured 
by the "/etc/resolv" file.

The [resolver](http://man7.org/linux/man-pages/man5/resolver.5.html) 
is a set of routines in the C library that provide
access to the Internet Domain Name System (DNS). The
configuration file is considered a trusted source of DNS information

    network.push name: 'Network # DNS Resolver', callback: (ctx, next) ->
      {resolv} = ctx.config.network
      return next null, ctx.INAPPLICABLE unless resolv
      # nameservers = []
      # re = /nameserver(.*)/g
      # while (match = re.exec resolv) isnt null
      #   nameservers.push match[1].trim()
      nameservers = ctx.hosts_with_module 'bind_server'
      # console.log nameservers, 53
      ctx.waitIsOpen nameservers, 53, (err) ->
        return next err if err
        ctx.write
          content: resolv
          destination: '/etc/resolv.conf'
          backup: true
        , (err, replaced) ->
          return next err, if replaced then ctx.OK else ctx.PASS

