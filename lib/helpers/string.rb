
require_relative 'log'
require 'cgi'

######
# some class improvements

class String
  def constantize
    names = self.split('::')
    names.shift if names.empty? || names.first.empty?

    constant = Object
    names.each do |name|
      constant = constant.const_defined?(name) ? constant.const_get(name) : constant.const_missing(name)
    end
    constant
  end

  # only get AsdfGfre from asdf_gfre
  def camelize
    self.split('_').map {|w| w.capitalize}.join
  end

  # simplified version of rails', only get asdf_gfre from AsdfGfre
  def underscore
    word = dup
    word.gsub!(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.tr!("-", "_")
    word.downcase!
  end

  def classify
    self.camelize
  end

  # remove surrounding ticks -->'<--
  def untick
    strip.sub(/^'/,'').sub(/'$/,'')
  end

  # remove surrounding square brackets
  def unsquare
    strip.sub(/^\[/,'').sub(/\]$/,'')
  end

  def readable_escape
    CGI.escape( self.strip.gsub(/\s+/,'_').gsub(/ñ/, 'n').gsub(/Ñ/, 'N').gsub(/,/, '').gsub(%r{\.}, '') )
  end
end

class Hash

  # gets an array of keys, if they exists inside the hash's keys,
  # they are converted to string keys
  #
  def stringify_keys!(*which)
    which = self.keys if which.none?
    which.each{ |s| self[s.to_s] = self.delete(s) if self[s] }
    self
  end

  # same as `stringify_keys!` but returning a new Hash
  #
  def stringify_keys(*which)
    h = self.dup
    h.stringify_keys!(*which)
  end

  def to_html_ul
    output = "<ul>"

    each do |key, value|
      if value.is_a?(Hash) || value.is_a?(Array)
        value = value.to_html_ul
      end

      output += "<li>#{key}: #{value}</li>"
    end

    output += "</ul>"
  end
end

class Array
  def to_html_ul
    output = "<ul>"

    each do |value|
      if value.is_a?(Hash) || value.is_a?(Array)
        value = value.to_html_ul
      end

      output += "<li>#{value}</li>"
    end

    output += "</ul>"
  end
end
