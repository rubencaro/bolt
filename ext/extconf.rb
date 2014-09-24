
=begin

  Fake extension building

  This allows for performing any install time logic, letting rubygems
  think we are compiling something...

  To fool rubygems we need a fake Makefile which can run `make all` and
  `make install`. Then we also need to place the fake `*.so` library, result of
  the fake Makefile.

=end

# Do whatever you want here

# Fake Makefile that fools rubygems
File.open('Makefile','w+') do |f|

f.write <<MF

all:
\t/usr/bin/touch ./bolt.so

install:

MF

end
