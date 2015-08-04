require 'time_formats'

class Fixnum
  include TimeFormats
end

class Bignum
  include TimeFormats
end
