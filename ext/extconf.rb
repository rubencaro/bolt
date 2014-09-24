
=begin

  Fake extension building

  This allows for putting our bash scripts on the path, letting rubygems
  think we are compiling something...

  To fool rubygems we need a fake Makefile which can run `make all` and
  `make install`. Then we also need to place the fake `*.so` library, result of
  the fake Makefile.

=end

puts "Putting scripts on path..."
