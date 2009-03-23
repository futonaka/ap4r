# Author:: Kiwamu Kato
# Copyright:: Copyright (c) 2007 Future Architect Inc.
# Licence:: MIT Licence

module Ap4r
  # Defines version number contants, and provides
  # its string expression.
  module VERSION #:nodoc:
    MAJOR = 0
    MINOR = 3
    TINY  = 7

    STRING = [MAJOR, MINOR, TINY].join('.')
  end
end
