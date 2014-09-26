# Bolt

He is a fast runner.

## What

Reads tasks from a mongo table called `task_queue` on a db called
`bolt_#{CURRENT_ENV}`, where `CURRENT_ENV` can be one of `production`,
`development`(the default) or `test`.

Tasks should be defined on separate files inside `bolt/tasks` folder, which
should be itself placed somewhere in load path (ex. inside `lib`).

Bolt will fork itself, and then it will load the ruby file placed in
`bolt/tasks/#{task}.rb`, where `task` is the value of the `task` field in the
mongo document. That file should define a module named with the camelized
version of the task's name. Bolt will call a method `run` that must be defined
for that module, passing the complete mongo document for this task.

Inside `bolt/tasks/my_example_task.rb` things look like this:

    module Bolt
      module Tasks
        module MyExampleTask

          def self.run(task:)
            do_something_with task
          end

        end
      end
    end

Bolt will use that same mongo document afterwards to send success (or failure)
emails depending on whether the execution ended normally or any exception was
raised.

By now, tasks are always removed from db when done.

Tasks are isolated on their own process, so they have freedom to do nasty
things. They won't corrupt Bolt or the other tasks. They can require any
gems allowed by the environment where Bolt is running.

Also, everything in the mongo document must be JSON serializable, as it has to
be passed through pipes when communicating between processes. Anything not
serializable will not be available for the task, or for the notification emails.

Fields on the mongo document and used by Bolt are:

* `task`: the name of the task, also of the module and the file defining it.
The only mandatory.
* `timeout`: timeout for the task to end. Default is 300 secs.
* `dispatched`: boolean indicating whether Bolt started processing that task.
* `success`: when defined, indicates the result of the execution.
* `ex`, `backtrace`: failure details when the task fails.
* `email`: email recipient for the notification emails. Defaults to
`tech+bolt at elpulgardelpanda.com`.
* `run_at`: timestamp for the start of the task. When it exists, task will not
be started by Bolt until it's in the past.

You are free to add as many fields as mongo can support. They will be passed
along to yout task.

## Use

Add it to your `Gemfile`, and add `stones` too:

    gem 'bolt', :git => 'git@github.com:epdp/bolt.git'
    gem 'stones', :git => 'git@github.com:epdp/stones.git'

Be careful with your `stones` version. It should match Bolt's needs. Freeze your
tags when your app is stable.

After `bundle install` you should run `bolt_setup` from your app's folder. That
will create a wrapper of the `bolt_watchdog` for that version of Bolt and for
your app. That is the script you should run from your `cron` every minute to
ensure Bolt is always up. Such as:

    * * * * * /bin/bash -l -c 'nice /path/to/app/bolt_watchdog'

## Running

On every loop of the main dispatcher, Bolt will run
`touch ~/flagella/timestamps/bolt__60__300` signalling it's still alive. That
file is meant to be monitorized by `luther`. `bolt` being all that's needed to
find the running process using `pgrep`, `60` the timeout to trigger a warning,
and `300` the timeout to consider Bolt is a useless zombie worth being killed.

Also Bolt will kill itself when it detects any change (a gentle `touch` is
enough) on `/path/to/app/tmp/kill.flagella` or `/path/to/app/tmp/kill.bolt`.
This is meant to be used on deploys or plain restarts. Write your tasks so they
can be interrupted at any time.

Logging will be done on `/path/to/app/log/flagella.log`.

All this folders and files should exist in production. You can create them by
yourself, or you can run `bundle exec bolt_setup` from your app's folder on
production to let bolt create them.


## Interrupting and recycling tasks

You should design your tasks (any software!) to be fault-tolerant. They can be
(will be!) interrupted at any time. Solar storms, sysops will, or devops fault
are only three normal causes for that.

Current Bolt implementation will _recycle_ tasks that were started and then
interrupted (i.e. Bolt will run them again). You should be aware of this and
code your task to be able to recover itself from the point it was interrupted,
or to be rerun without harm.

Just try to write functional code and everything will flow.


## Developing

Testing: `ruby -Itest test/all.rb`

Work in branches. When you branch is merged into master
[semantic versioning](https://semver.org) will be used for tagging.

Take a look at the code for more details...

## TODOs

* Expose configurable things.
* Finish already planned testing.
* Reduce Bolt weight as much as possible.
* Add periodic task support.
* Maybe add persistence of task in db (maybe a history/log in a capped
collection).
* Support non interruptible tasks.
* Document standalone deploy.


## Read the code

Please read the code of the gems you use. Make the world a better place.

