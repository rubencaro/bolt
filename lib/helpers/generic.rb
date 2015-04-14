
module Helpers
  module Generic
    def check_args(passed, required, hash_response = false)
      passed_required_args = required & passed.keys
      if passed_required_args != required then
        msg = "Missing arguments: #{required - passed_required_args}"
        if hash_response then
          return { :valid => false, :errors => msg }
        end
        raise ArgumentError.new msg
      end
      if hash_response then
        return { :valid => true }
      end
      true
    end
  end

  extend Generic
end

H = Helpers if not defined? H

class Module
  def subclasses
    ObjectSpace.to_enum(:each_object, Module).select do |m|
      m.ancestors.include?(self)
    end.reject { |m| m == self }
  end
end

class Hash

  # Set a value on given coords inside a hash of hashes.
  # Create the hierarchy if it does not exist.
  #
  # `coords_and_value` is an array of keys, and the value is the last one
  #
  # Example:
  #   hash.set! :a,:b,:c,value
  #

  def set!(*coords_and_value, base: self)
    return if coords_and_value.count < 2

    if coords_and_value.count == 2 then
      k,v = coords_and_value
      base[k] = v
      return
    end

    k = coords_and_value.shift
    base[k] = {} if not base[k].is_a? Hash
    set! *coords_and_value, :base => base[k]
  end

  # Get a value on given coords inside a hash of hashes.
  # Return nil if any coord does not exist.
  #
  # `coords` is an array of keys
  #
  # Example:
  #   hash.get? :a,:b,:c
  #
  def get?(*coords, base: self)
    return base[coords.first] if coords.count == 1

    base = base[coords.shift]
    return nil if not base.is_a? Hash
    get? *coords, :base => base
  end

  # Revert the order of a hash by key
  #
  def reverse
    self.keys.reverse.inject({}){|h,k| h[k] = self[k]; h}
  end

end
