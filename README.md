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

```ruby
    module Bolt
      module Tasks
        module MyExampleTask

          def self.run(args)
            do_something_with args[:task]
          end

        end
      end
    end
```

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

The structure of the mongo document passed to your task may be different from
the one you could expect directly from the mongo client. It has been serialized
and deserialized. For example, the document `_id` is found in
`task['_id']['$oid']` instead of `task['_id']`, because of the serialization of
the `BSON::ObjectId` instance that lived in `task['_id']`. Bolt recreates the
`BSON::ObjectId` for you before yielding the task to your task, so you don't
have to worry about that. But ok, it was just an example...

Bolt defines a module `Bolt::Helpers` meant to be used form inside your tasks.
For example, you can grab a connection to Bolt's queue, that lives inside a
mongo collection, by calling `Bolt::Helpers.get_mongo_collection` anywhere in
your code.

Fields on the mongo document and used by Bolt are:

* `task`: the name of the task, also of the module and the file defining it.
The only mandatory.
* `timeout`: timeout for the task to end. Default is 300 secs.
* `dispatched`: boolean, whether Bolt started processing that task.
* `success`: when defined, indicates the result of the execution.
* `ex`, `backtrace`: failure details when the task fails.
* `email`: email recipient for the notification emails. Defaults to
`tech+bolt at elpulgardelpanda.com`.
* `run_at`: timestamp for the start of the task. When it exists, task will not
be started by Bolt until it's in the past.
* `persist`: boolean, don't remove the task after it's done, save it instead
* `finished`: boolean, whether Bolt ended processing that task (only makes sense
if `persist`...).
* `silent`: don't send email notifications unless the task fails and `persist`
is `false`.
* `expire`: remove from db when this Date arrives. If it's not there, doc is not
removed.

You are free to add as many fields as mongo can support. They will be passed
along to your task.


## Use

Add it to your `Gemfile`, and add `stones` too:

```ruby
    gem 'bolt', :git => 'git@github.com:epdp/bolt.git'
    gem 'stones', :git => 'git@github.com:epdp/stones.git'
```

Be careful with your `stones` version. It should match Bolt's needs. Freeze your
tags when your app is stable.

As your task will run in a fork from Bolt itself, you should take a look at what
Bolt has already loaded when your task starts. It's meant to evolve towards a
minimum, reaching it someday.

After `bundle install` you should run `bolt_setup` from your app's folder. That
will create a wrapper of the `bolt_watchdog` for that version of Bolt and for
your app. That is the script you should run from your `cron` every minute to
ensure Bolt is always up. Such as:

```bash
    * * * * * /bin/bash -l -c 'nice /path/to/app/bolt_watchdog'
```

`bolt_setup` will also create a `config/bolt.rb` file that will be loaded by
Bolt once when it starts. There you want to put your initialization code for
`stones`, for example.


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


## Queueing tasks for Bolt

Someone should put tasks in the queue for Bolt to process. How this is done
depends really on the place from where you do it. From generic ruby code one
could do this:

```ruby
    require 'bolt' # that already loads bolt's config

    # the task's hash
    task_data = { :task => 'my_task',  # it's defined on bolt/tasks/my_task.rb
                  :email => 'notify@only.to.me', # add any other Bolt parameters
                  :more => 'data' }    # anything else, it's a mongo doc

    # this will use a plain mongo client
    Bolt::Helpers.schedule task_data

    # you can use your own special client
    coll = MySpecialMongoClient.new(Bolt.db)[Bolt.queue]
    coll.insert task_data # it's mongo, just do it!
```


## Persistence

If `persist` is set, then everything put in the task will persist along with it.
The task code itself is responsible for saving any data on the task instance
before control is passed back to Bolt. Just like:

```ruby
    module Bolt::Tasks
      module Subtask
        def self.run(args)
          do_something_with args[:task]

          # save results somewhere in the task, it's a mongo doc!
          args[:task]['results'] = { :everything => "fine from subtask" }
        end
      end
    end
```

Of course, it can also perform writes to db at any time. That can be useful
sometimes to save the state and be able to recover afterwards from a system
failure. Such as:

```ruby
    module Bolt::Tasks
      module Mytask
        def self.run(args)
          # get access to db
          coll = Bolt::Helpers.get_mongo_collection

          t = args[:task]

          # recover previous state, or start with 10
          rounds = 10 - t['already_done'].to_i

          rounds.times do |round|
            do_something_with t, round
            # save state
            coll.update({'_id' => t['_id']},
                        { '$set' => {'already_done' => round + 1} })
          end
        end
      end
    end
```


## Notifications

Bolt will send an email to the address put in the `email` field in the task when
the task ends. There are two main email templates, one for success, one for
failure. You can override their subject or their body by setting some options
in the task. Bolt will lok for those options and will use them if they are
found.

```ruby
    module Bolt
      module Tasks
        module MyExampleTask

          def self.run(args)
            do_something_with args[:task]

            # setup notification emails
            args[:task].set! 'opts','email','success','subject','My success subject'
            args[:task].set! 'opts','email','success','body','My success body'
            args[:task].set! 'opts','email','failure','subject','My failure subject'
            args[:task].set! 'opts','email','failure','body','My failure body'
          end

        end
      end
    end
```

If you set the `silent` option in the task, then:

* No email will be sent on success.
* No email will be sent on failure if `persist` is also set to `true`.
* Email will be sent on failure when `persist` is not `true`.


## Composite tasks

You can create tasks that schedule, run and report other tasks. You only need to
use `Bolt` helpers to schedule the tasks, and then to retrieve them afterwards.
The mongo document itself can be used to persist the task outcome. Like this:

```ruby
    module Bolt::Tasks
      module Composite
        def self.run(args)
          bh = Bolt::Helpers # namespaces are good

          # schedule A
          idA = bh.schedule_subtask :task => 'my_taskA', :more => 'data'

          # schedule B
          idB = bh.schedule_subtask :task => 'my_taskB', :more => 'data'

          # wait for A
          res = bh.wait_for idA

          raise "Oh no! #{res[:ex]}" if not res[:valid]  # task did not finish on time

          do_something_with res[:task]['results']   # or wherever the A task saved them

          # go on with B ...

        ensure  # remember to clean up
          bh.remove idA if idA
          bh.remove idB if idB
        end
      end
    end
```

`schedule_subtask` inserts the given task into the queue with some options
suitable for subtasks, such as `persist`, `expire` and `silent`. Do not override
them if you don't want to interfere with it's expected process.

`wait_for` returns `{ :valid => false, :ex => <exception>}` if the task is not
finished on time. Your task should handle the situation when it comes.


## Interrupting and recycling tasks

You should design your tasks (any software!) to be fault-tolerant. They can be
(will be!) interrupted at any time. Solar storms, sysops will, or devops fault
are only three normal causes for that.

Current Bolt implementation will _recycle_ tasks that were started and then
interrupted (i.e. Bolt will run them again). You should be aware of this and
code your task to be able to recover itself from the point it was interrupted,
or to be rerun without harm.

Just try to write functional code and everything will flow.


## Run in development

To run Bolt in a development environment you just need to open a interactive
Ruby session and `require 'bolt'` and any other libraries you may need from your
project. Just like:

```
    $ pry -Ilib
    [1] pry(main)> require 'bolt'
    => true
    [2] pry(main)> Bolt.dispatch_loop tasks_count: 1, rounds: 3, tasks_wait: 0.5

    (...Bolt running stdout...)

    [3] pry(main)>
```

Control your mongo queue from mongo client:

```
    $ mongo
    MongoDB shell version: 2.6.5
    connecting to: test
    > use bolt_development
    switched to db bolt_development
    > db.task_queue.find();
    >
```


## Testing tasks

If your task interacts with Bolt you may want to test it together with Bolt. As
long as you configure `stones` to be in the test environment, you should be able
to test your tasks like this:

```ruby
    CURRENT_ENV = 'test' # your app's env
    require 'config/stones' # your app's stones' config
    require 'helpers/test/basic' # BasicTestCase, or use your own TestCase class

    # all code above usually will go on some kind of test_helper file
    # but this way you can see actual Bolt dependencies for test

    require 'bolt'
    require 'mail' # to assert email sending

    class YourTaskTest < BasicTestCase

      def setup
        @coll = Bolt::Helpers.get_mongo_collection  # will be the testing one
        @coll.remove # clear the queue
        Mail::TestMailer.deliveries.clear
        Bolt::Helpers.save_tasks! # to save task documents with their test_metadata
      end

      def test_it_goes_on_inside_bolt
        # add the task to the queue
        Bolt::Helpers.schedule :task => 'your_task', :anything => 'else'

        # call dispatch_loop, processing only one task and leave
        Bolt.dispatch_loop :tasks_count => 1

        # check anything you expected
        assert_equal 1, Mail::TestMailer.deliveries.count # it sent an email
        assert @coll.find().to_a.none? # queue is clean
        tasks = Bolt::Helpers.tasks # saved tasks
        assert_equal 1, tasks.count, tasks
        md = tasks.first['test_metadata'] # gathered test_metadata
        assert_equal 38, md['system']['calls'].count, md
      end

    end
```

Remember that Bolt forks itself and runs the task on that forked process. That
means that the only way of communication is using the pipe (or using an external
service). Bolt provides a mechanism to save a task's process' metadata, gathered
by stones' helpers, on the task document under the key `test_metadata`. That
task is then passed through the pipe and saved for you on `Bolt::Helpers.tasks`
in the master process. Luckily that's the process you're running the test from.
To activate the mechanism you should be on the `test` environment and run
`Bolt::Helpers.save_tasks!`.

To test a composite task you should play with `dispatch_loop`'s parameters.
Like this:

```ruby
    Bolt.dispatch_loop :tasks_count => 1, :rounds => 3, :tasks_wait => 0.5
```

That will wait at most 0.5 seconds (`tasks_wait`) until it sees 1 task available
(`tasks_count`) to run. Then it will start running it, and then wait again at
most `tasks_wait` seconds for `tasks_count` tasks to be available for run.
Bolt will repeat that 3 times (`rounds`). After that it will wait until every
task is finished. This example is suitable for a task that schedules 2 subtasks.


## TODOs

* Expose configurable things.
* Reduce Bolt weight as much as possible.
* Add periodic task support.
* Support non interruptible tasks.
* Document standalone deploy.


## Read the code

Please read the code of the gems you use. Make the world a better place.


## Developing

Testing: `ruby -Itest test/all.rb`

Work in branches. When you branch is merged into master
[semantic versioning](https://semver.org) will be used for tagging.

Take a look at the code for more details...


## Changelog

### 0.3.0

* Add throttle
* Add silent
* Add persist
* Add composite tasks
* Add more helpers

### 0.2.0

* First production version
