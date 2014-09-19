#!/usr/bin/env bash

# esto es ejecutado por el cron cada x minutos y debe comprobar que el wrapper está vivo
# si no, debe reiniciar el wrapper

# on crontab:
#    * * * * * /bin/bash -l -c '/path/to/bolt_watchdog.sh'

directory=$(cd `dirname $0` && pwd)
app="$directory/../.."
logs="$app/log/flagella.log"
flagellum="bolt.rb"
command="$directory/$flagellum"

. $app/lib/shell_helpers.sh

# comprobar que solo se esta ejecutando un proceso flagelo, y si no saca el hacha
check_multiple_flagella "$directory" "$flagellum" >> $logs

# echo "------ CARNAGE: $CARNAGE   --------   FLAGELLUM_PROCESS_COUNT: $FLAGELLUM_PROCESS_COUNT " >> $logs

# comprobar flagelo
[ $FLAGELLUM_PROCESS_COUNT -gt 0 ] && [ $CARNAGE -eq 0 ] && exit 0

# arrancar flagelo
. $HOME/.bash_profile
export CURRENT_ENV=production
cd $app
bundle exec ruby $command &>> $logs &
wait_for_process spawn $command 30
[ $? -ne 0 ] && echo "Exception: Could not spawn '$command'." | tee -a $logs && exit 1

echo "--- $(date) --- '$command' ha sido iniciado." >> $logs
exit 0
