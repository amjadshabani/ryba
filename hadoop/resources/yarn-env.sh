
export HADOOP_YARN_HOME={{ryba.yarn.home}}
export YARN_LOG_DIR={{ryba.yarn.log_dir}}/$USER
export YARN_PID_DIR={{ryba.yarn.pid_dir}}/$USER
export HADOOP_LIBEXEC_DIR={{ryba.hadoop_libexec_dir}}
export JAVA_HOME={{java.java_home}}

# We need to add the EWMA appender for the yarn daemons only;
# however, YARN_ROOT_LOGGER is shared by the yarn client and the
# daemons. This is restrict the EWMA appender to daemons only.
INVOKER="${0##*/}"
if [ "$INVOKER" == "yarn-daemon.sh" ]; then
  export YARN_ROOT_LOGGER=${YARN_ROOT_LOGGER:-INFO,EWMA,RFA}
fi

# User for YARN daemons
export HADOOP_YARN_USER=${HADOOP_YARN_USER:-yarn}

# resolve links - $0 may be a softlink
export YARN_CONF_DIR="${YARN_CONF_DIR:-$HADOOP_YARN_HOME/conf}"

# some Java parameters
# export JAVA_HOME=/home/y/libexec/jdk1.6.0/
if [ "$JAVA_HOME" != "" ]; then
#echo "run java in $JAVA_HOME"
JAVA_HOME=$JAVA_HOME
fi

if [ "$JAVA_HOME" = "" ]; then
echo "Error: JAVA_HOME is not set."
exit 1
fi

JAVA=$JAVA_HOME/bin/java
JAVA_HEAP_MAX=-Xmx1000m

# For setting YARN specific HEAP sizes please use this
# Parameter and set appropriately
YARN_HEAPSIZE={{ryba.yarn.heapsize}}

# check envvars which might override default args
if [ "$YARN_HEAPSIZE" != "" ]; then
JAVA_HEAP_MAX="-Xmx""$YARN_HEAPSIZE""m"
fi

# Resource Manager specific parameters

# Specify the max Heapsize for the ResourceManager using a numerical value
# in the scale of MB. For example, to specify an jvm option of -Xmx1000m, set
# the value to 1000.
# This value will be overridden by an Xmx setting specified in either YARN_OPTS
# and/or YARN_RESOURCEMANAGER_OPTS.
# If not specified, the default value will be picked from either YARN_HEAPMAX
# or JAVA_HEAP_MAX with YARN_HEAPMAX as the preferred option of the two.
export YARN_RESOURCEMANAGER_HEAPSIZE={{ryba.yarn.rm.heapsize}}

# Specify the JVM options to be used when starting the ResourceManager.
# These options will be appended to the options specified as YARN_OPTS
# and therefore may override any similar flags set in YARN_OPTS
#export YARN_RESOURCEMANAGER_OPTS=

# Ryba: user defined YARN RM options
export YARN_RESOURCEMANAGER_OPTS="${YARN_RESOURCEMANAGER_OPTS} {{ryba.yarn.rm.opts}}" # RYBA CONF "ryba.yarn.rm.opts", DONT OVERWRITE"

# Node Manager specific parameters

# Specify the max Heapsize for the NodeManager using a numerical value
# in the scale of MB. For example, to specify an jvm option of -Xmx1000m, set
# the value to 1000.
# This value will be overridden by an Xmx setting specified in either YARN_OPTS
# and/or YARN_NODEMANAGER_OPTS.
# If not specified, the default value will be picked from either YARN_HEAPMAX
# or JAVA_HEAP_MAX with YARN_HEAPMAX as the preferred option of the two.
export YARN_NODEMANAGER_HEAPSIZE={{ryba.yarn.nm.heapsize}}

# Specify the max Heapsize for the HistoryManager using a numerical value
# in the scale of MB. For example, to specify an jvm option of -Xmx1000m, set
# the value to 1024.
# This value will be overridden by an Xmx setting specified in either YARN_OPTS
# and/or YARN_HISTORYSERVER_OPTS.
# If not specified, the default value will be picked from either YARN_HEAPMAX
# or JAVA_HEAP_MAX with YARN_HEAPMAX as the preferred option of the two.
export YARN_HISTORYSERVER_HEAPSIZE={{ryba.yarn.ats.heapsize}}
# Ryba: user defined YARN RM options
export YARN_HISTORYSERVER_OPTS="${YARN_HISTORYSERVER_OPTS} {{ryba.yarn.ats.opts}}" # RYBA CONF "ryba.yarn.rm_opts", DONT OVERWRITE"

# Specify the JVM options to be used when starting the NodeManager.
# These options will be appended to the options specified as YARN_OPTS
# and therefore may override any similar flags set in YARN_OPTS
#export YARN_NODEMANAGER_OPTS=

# Ryba: user defined YARN RM options
export YARN_NODEMANAGER_OPTS="${YARN_NODEMANAGER_OPTS} {{ryba.yarn.nm.opts}}" # RYBA CONF "ryba.yarn.rm_opts", DONT OVERWRITE"

# so that filenames w/ spaces are handled correctly in loops below
IFS=


# default log directory and file
if [ "$YARN_LOG_DIR" = "" ]; then
YARN_LOG_DIR="$HADOOP_YARN_HOME/logs"
fi
if [ "$YARN_LOGFILE" = "" ]; then
YARN_LOGFILE='yarn.log'
fi

# default policy file for service-level authorization
if [ "$YARN_POLICYFILE" = "" ]; then
YARN_POLICYFILE="hadoop-policy.xml"
fi

# restore ordinary behaviour
unset IFS

# Imported from old templating system but might no longer be necessary
YARN_IDENT_STRING=${YARN_IDENT_STRING:-yarn} # RYBA FIX rc.d

YARN_OPTS="$YARN_OPTS -Dhadoop.log.dir=$YARN_LOG_DIR"
YARN_OPTS="$YARN_OPTS -Dyarn.log.dir=$YARN_LOG_DIR"
YARN_OPTS="$YARN_OPTS -Dhadoop.log.file=$YARN_LOGFILE"
YARN_OPTS="$YARN_OPTS -Dyarn.log.file=$YARN_LOGFILE"
YARN_OPTS="$YARN_OPTS -Dyarn.home.dir=$YARN_COMMON_HOME"
YARN_OPTS="$YARN_OPTS -Dyarn.id.str=$YARN_IDENT_STRING"
YARN_OPTS="$YARN_OPTS -Dhadoop.root.logger=${YARN_ROOT_LOGGER:-INFO,console}"
YARN_OPTS="$YARN_OPTS -Dyarn.root.logger=${YARN_ROOT_LOGGER:-INFO,console}"
if [ "x$JAVA_LIBRARY_PATH" != "x" ]; then
YARN_OPTS="$YARN_OPTS -Djava.library.path=$JAVA_LIBRARY_PATH"
fi
YARN_OPTS="$YARN_OPTS -Dyarn.policy.file=$YARN_POLICYFILE"

# Ryba: user defined YARN options
export YARN_OPTS="${YARN_OPTS} {{ryba.yarn.opts}}" # RYBA CONF "ryba.yarn.opts", DONT OVERWRITE"
