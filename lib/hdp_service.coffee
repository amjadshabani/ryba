
###

Options include
*   `startup`: [true] or false
*   `link`: [true]
*   `write`: array
*   `name`
*   `version`
*   `version_name`
*   `etc_default` (string, array, object)
     List of filename present inside "hdp/{version}/etc/rc.d" directory to symlink
     from "/etc/rc.d", default to options.name.
###

module.exports = (ctx) ->
  return if ctx.registered 'hdp_service'
  ctx.register 'hdp_service', (options, callback) ->
  # ctx.hdp_service = (options, callback) ->
    # options = name: options if typeof options is 'string'
    # wrap null, arguments, (options, callback) ->
    status = false
    options.startup ?= false
    options.version_name ?= options.name
    return callback Error "Missing Option 'name'" unless options.name
    version=''
    options.version ?= 'latest'
    do_service = =>
      @service
        name: "#{options.name}"
      , (err, updated) ->
        return do_end err if err
        status = true if updated
        do_link()
    do_link = =>
      options.etc_default ?= true
      etc_default = options.etc_default
      etc_default = options.name if etc_default is true
      etc_default = [etc_default] if typeof etc_default is 'string'
      if Array.isArray etc_default
        options.etc_default = {}
        for name in etc_default
          options.etc_default[name] = {}
      @execute
        cmd: """
        code=3
        if [ "#{options.version}" == "latest" ]; then
          version=`hdp-select versions | tail -1`
        elif [ "#{options.version}" == "current" ]; then
          version=`hdp-select status #{options.version_name} | sed 's/.* \\(.*\\)/\\1/'`
          if [ "$version" == "None" ]; then
            version=`hdp-select versions | tail -1`
          fi
        else
          version='#{options.version}'
        fi
        if [ ! -d "/usr/hdp/$version" ]; then
          echo 'Failed to detect the latest HDP version'
          exit 1
        fi
        echo $version
        hdp-select set #{options.version_name} $version
        # Deal with "rc.d" startup scripts
        source="/etc/init.d/#{options.name}"
        target="/usr/hdp/$version/etc/rc.d/init.d/#{options.name}"
        create=1
        if [ -L $source ]; then
          current=`readlink $source`
          if [ ! -f $target ]; then exit 1; fi
          if [ "$target" == "$current" ]; then
            create=0
          fi
        fi
        if [ $create == '1' ]; then
          ln -sf $target $source
          code=0
        fi
        # Deal with "/etc/default" environment scripts
        for filename in #{Object.keys(options.etc_default).join(' ')}; do
          source="/etc/default/$filename"
          target="/usr/hdp/$version/etc/default/$filename"
          if [ ! -f $target ]; then
            if [ $source == "/etc/default/#{options.name}" ]; then continue; else exit 1; fi
          fi
          create=1
          if [ -L $source ]; then
            current=`readlink $source`
            if [ "$target" == "$current" ]; then
              create=0
            fi
          fi
          if [ "$create" == '1' ]; then
            ln -sf $target $source
            code=0
          fi
        done
        exit $code
        """
        code_skipped: 3
      , (err, linked, stdout, stderr) ->
        return do_end err if err
        version = string.lines(stdout)[0]
        options.log? "ryba `hdp_server`: package link updated for '#{options.name}' [WARN]" if linked
        status = true if linked
        do_startup()
    do_startup = =>
      @service
        srv_name: "#{options.name}"
        startup: options.startup
      , (err, startuped) ->
        return do_end err if err
        options.log? "ryba `hdp_server`: startup changed for '#{options.name}' [WARN]" if startuped
        status = true if startuped
        do_write()
    do_write = =>
      return do_write_etc_default() unless options.write
      @write
        destination: "/usr/hdp/#{version}/etc/rc.d/init.d/#{options.name}"
        write: options.write
        backup: true
      , (err, written) ->
        return do_end err if err
        options.log? "ryba `hdp_server`: file '/usr/hdp/#{version}/etc/rc.d/init.d/#{options.name}' modified [WARN]" if written
        status = true if written
        do_write_etc_default()
    do_write_etc_default = =>
      each options.etc_default
      .run (name, options_etc_default, next) =>
        return next() unless options_etc_default.write
        @write
          destination: "/usr/hdp/#{version}/etc/default/#{name}"
          write: options_etc_default.write
          backup: true
        , (err, written) ->
          return next err if err
          options.log? "ryba `hdp_server`: file '/etc/default/#{name}' modified [WARN]" if written
          status = true if written
          next()
      .then (err) -> do_end err, status
    do_end = (err) ->
      callback err, status
    do_service()
    # .then (err) -> callback err, status

each = require 'each'
wrap = require 'mecano/lib/misc/wrap'
string = require 'mecano/lib/misc/string'
