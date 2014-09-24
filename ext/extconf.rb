
=begin

  Fake extension building

  This allows for putting our bash scripts on the path, letting rubygems
  think we are compiling something...

  To fool rubygems we need a fake Makefile which can run `make all` and
  `make install`. Then we also need to place the fake `*.so` library, result of
  the fake Makefile.

=end

require 'rubygems'
require 'bundler/setup'

app_path = File.dirname ENV['BUNDLE_GEMFILE']

puts "Putting actual executable on #{app_path}..."

`ln -sf #{File.expand_path('../bin')}/bolt_watchdog #{app_path}`

puts "Fooling rubygems..."

# fake Makefile
File.open('Makefile','w+') do |f|

f.write <<MF

all:
\t/usr/bin/touch ./bolt.so

install:

MF

end
