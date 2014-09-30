
# cat 'partial' into 'base' and remove 'partial'
# Usage: consolidate 'partial' 'base'
#
function consolidate {
  local partial=${1?}
  local base=${2?}
  cat $partial >> $base
  rm $partial
}

# cat 'partial' and then consolidate 'partial' 'base'
# Usage: cat_consolidate 'partial' 'base'
#
function cat_consolidate {
  local partial=${1?}
  local base=${2?}
  echo
  echo
  echo "      Operation log:"
  echo
  echo
  cat $partial
  consolidate $partial $base
}

# Check given command returns given return_code
# Usage: check_return_code 'return_code' 'cmd' <'arg' 'arg' ... >
#
function check_return_code {
  local return_code="${1?}"
  shift
  local cmd="$@"
  eval "$cmd"
  [[ "$?" == "$return_code" ]] && return 0 || return 1;
}

# Waits until given cmd show given return_code, max 'timeout' secs
# Usage: wait_for 'return_code' 'cmd' <'timeout'>
#
# 'timeout' is 120 by default
#
function wait_for {
  local return_code="${1?}"
  local cmd="${2?}"
  local timeout_secs="${3:-120}"
  local n=0

  while ! check_return_code "$return_code" "$cmd"; do
    n=$((n+1))
    echo "[$(date +'%F %T')] Waiting for $return_code on -> $cmd <-"
    if [ $n -gt $timeout_secs ]; then
      echo "[$(date +'%F %T')] Didn't get $return_code from '$cmd' ! Waited $timeout_secs secs. Exiting."
      return 1
    fi
    sleep 1
  done
  return 0
}

########
# puma restart control helpers

function get_puma_stats {
  local appdir="${1?}"
  echo $(bundle exec pumactl -F $appdir/config/puma.rb stats | grep workers | sed 's/^.*"workers": \([0-9]\+\),.*"booted_workers": \([0-9]\+\).*$/\1 \2/')
}

# returns 1 if failed, 0 if all ok
function all_puma_workers_up {
  local appdir="${1?}"
  local stats="$(get_puma_stats $appdir)"
  local workers="$(echo "$stats" | awk '{print $1}')"
  local booted="$(echo "$stats" | awk '{print $2}')"
  [ "$workers" == "$booted" ] && return 0
  return 1
}

function wait_for_puma_phased_restart {
  local appdir="${1?}"
  local timeout_secs="${2:-30}"
  local cmd="all_puma_workers_up $appdir > /dev/null"
  wait_for 0 "$cmd" "$timeout_secs"
  [ $? -eq 0 ] && echo "[$(date +'%F %T')] I saw all puma's workers up! "
}

# returns 1 if failed, 0 if all ok
function puma_is_git_release {
  local appdir="${1?}"
  local running="$(curl -s http://localhost/version)"
  local current="$(git --git-dir=$appdir/.git rev-parse HEAD)"
  [ "$running" == "$current" ] && return 0
  return 1
}

function wait_for_puma_git_release {
  local appdir="${1?}"
  local timeout_secs="${2:-30}"
  local cmd="puma_is_git_release $appdir > /dev/null"
  wait_for 0 "$cmd" "$timeout_secs"
  [ $? -eq 0 ] && echo "[$(date +'%F %T')] I saw current release on server! "
}

###########


# Wait for a process 'action', max 'timeout' secs
# Usage: wait_for_process 'action' 'processname' <'timeout'>
#
# 'action' can be one of ['spawn','death'], otherwise default to 'spawn'
# 'timeout' is 120 by default
#
function wait_for_process {
  local action="${1?}"
  local processname="${2?}"
  local timeout_secs="${3:-120}"

  # choose exit code to check
  local code=0
  [ "death" = "$action" ] && code=1

  local cmd="pgrep -f '$processname' > /dev/null"
  wait_for "$code" "$cmd" "$timeout_secs"
  [ $? -eq 0 ] && echo "[$(date +'%F %T')] I saw $processname's $action ! "
}

# Wait for a file to be touched, max 'timeout' secs
# Usage: wait_for_touch 'filename' <'timeout'>
#
# 'timeout' is 120 by default
#
function wait_for_touch {
  local timeout_secs="${2:-120}"
  local filename="${1?}"
  local mtime_ts=$(get_file_mtime_ts "$filename")
  local mtime_ttl=$(get_file_mtime_ttl "$filename")

  local cmd="file_has_been_touched '$filename' $mtime_ttl"

  wait_for 0 "$cmd" "$timeout_secs"
  [ $? -eq 0 ] && echo "[$(date +'%F %T')] $filename has been touched! "
}

# file_has_been_touched 'filename' 'ttl'
function file_has_been_touched {
  [ $(($(date +%s)-$(get_file_mtime_ts ${1?}))) -lt ${2?} ]
}

# Wait for a socket to be able to 'action', max 'timeout' secs
# Usage: wait_for_socket 'action' 'filename' <'timeout'>
#
# 'action' can be one of ['connect','disconnect'], otherwise default to 'connect'
# 'timeout' is 120 by default
#
function wait_for_socket {
  local timeout_secs="${3:-120}"
  local action="${1?}"
  local filename="${2?}"

  # choose exit code to check
  local code=0
  [ "disconnect" = "$action" ] && code=1

  local cmd="nc -w1 -U '$filename' < /dev/null &> /dev/null"
  wait_for "$code" "$cmd" "$timeout_secs"
  [ $? -eq 0 ] && echo "[$(date +'%F %T')] I saw $filename $action ! "
}

# Wait for a host:port to be able to 'action', max 'timeout' secs
# Usage: wait_for_tcp 'action' 'host' 'port' <'timeout'>
#
# 'action' can be one of ['connect','disconnect'], otherwise default to 'connect'
# 'timeout' is 120 by default
#
function wait_for_tcp {
  local timeout_secs=${4:-120}
  local action="${1?}"
  local host="${2?}"
  local port="${3?}"

  # choose exit code to check
  local code=0
  [ "disconnect" = "$action" ] && code=1

  local cmd="nc -w1 '$host' $port < /dev/null &> /dev/null"
  wait_for "$code" "$cmd" "$timeout_secs"
  [ $? -eq 0 ] && echo "[$(date +'%F %T')] I saw $host:$port $action ! "
}

# mtime in seconds
#
# Usage: get_file_mtime_ts 'filename'
#
function get_file_mtime_ts {
  ls -l --time-style=+%s "${1?}" |  cut -d' ' -f6
}

# Devuelve el ttl
#
# Usage: get_file_mtime_ttl 'filename'
#
# El formato del nombre de archivo es:
#  <nombre>__<ttl>__<zombie ttl>__<nombre pgrep>
#
function get_file_mtime_ttl {
  basename "${1?}" | awk -F__ '{ print $2 }'
}

# $ containsElement "a string" "${array[@]}"
function containsElement {
  local e
  for e in "${@:2}"; do [[ "$e" == "$1" ]] && return 1; done
  return 0
}

######################
#  Multiple flagella control helpers


# Se encarga de matar todos los procesos si detecta que hay más de uno.
#
# También establece dos variables que pueden ser útiles en el entorno que hace la llamada:
#    FLAGELLUM_PROCESS_COUNT  -> el número de flagelos detectado
#    CARNAGE  ->  0: no hubo carnicería, 1: se mataron todos los procesos con el nombre dado
#
# Usage: check_multiple_flagella 'directory' 'flagellum'
#
function check_multiple_flagella {
  local directory="${1?}"
  local flagellum="${2?}"

  # comprobar que solo se esta ejecutando un proceso flagelo, y si no saca el hacha
  local processes=$(ps ax -F | grep -v grep | grep ".*ruby $directory/$flagellum")
  local pids=$(echo "$processes" | awk '{print $2}')
  local ppids=$(echo "$processes" | awk '{print $3}' | grep -v '\b1\b') # there are no wrappers for haroche, pid 1 is normal!
  local all_pids=( $pids $ppids )
  local unique_pids=( $(printf '%s\n' "${all_pids[@]}" | sort -n | uniq) )
  containsElement "1" "${all_pids[@]}"
  local has_init=$?
  local kill_everyone=0

  FLAGELLUM_PROCESS_COUNT=$(echo $pids | wc -w)
  CARNAGE=0
  [ $FLAGELLUM_PROCESS_COUNT -gt 1 ] && echo "+++ $(date) +++ Multiples pids all:${all_pids[@]} unique:${unique_pids[@]}"

  [ $has_init -gt 0 ] && kill_everyone=0 && echo "+++ $(date) +++ pid 1 detected in all:${all_pids[@]}"

  [ $FLAGELLUM_PROCESS_COUNT -gt 1 ] && [ ${#all_pids[@]} -eq ${#unique_pids[@]} ] && kill_everyone=1

  [ $kill_everyone -gt 0 ] && {
    echo "+++ $(date) +++ Multiples flagelos $flagellum! pids: ${pids} Matandolos a todos..."
    echo "processes: $processes"
    kill -KILL $pids
    CARNAGE=1
  }
}



# Hace un ls de la carpeta dada, que debe contener solo archivos cuyo
#   nombre es un PID. Típicamente creados haciendo touch desde el proceso que
#   debe ser único.
# Entonces borra los pids que ya no estén vivos.
# Solo quedan los pids que estén realmente vivos.
#
# Si hay más de uno, los mata todos.
#
# También establece dos variables que pueden ser útiles en el entorno que hace la llamada:
#    FLAGELLUM_PROCESS_COUNT  -> el número de flagelos detectado
#    CARNAGE  ->  0: no hubo carnicería, 1: se mataron todos los procesos con el nombre dado
#
# Usage: check_pids_folder_for_uniqueness 'directory'
#
function check_pids_folder_for_uniqueness {
  local folder="${1?}"
  local kill_everyone=0

  local pids=( $(ls $folder) )

  local alive_pids=( )
  for pid in ${pids[@]}; do
    [ -d /proc/$pid ] && alive_pids+=( $pid )
    [ -d /proc/$pid ] || rm $folder/$pid
  done

  containsElement "1" "${pids[@]}"
  local has_init=$?

  FLAGELLUM_PROCESS_COUNT=${#alive_pids[@]}
  CARNAGE=0
  [ $FLAGELLUM_PROCESS_COUNT -gt 1 ] && echo "+++ $(date) +++ Multiples pids all:${pids[@]} alive:${alive_pids[@]}"

  [ $has_init -gt 0 ] && kill_everyone=0 && echo "+++ $(date) +++ pid 1 detected in all:${pids[@]}"

  [ $FLAGELLUM_PROCESS_COUNT -gt 1 ]  && kill_everyone=1

  [ $kill_everyone -gt 0 ] && {
    echo "+++ $(date) +++ Multiples procesos vivos en $folder ! pids: ${alive_pids[@]} Matandolos a todos..."
    kill -KILL $pids
    rm $folder/*
    CARNAGE=1
  }

}



#########
