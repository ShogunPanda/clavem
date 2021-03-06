# encoding: utf-8
#
# This file is part of the clavem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

module Clavem
  # The current version of clavem, according to semantic versioning.
  #
  # @see http://semver.org
  module Version
    # The major version.
    MAJOR = 2

    # The minor version.
    MINOR = 2

    # The patch version.
    PATCH = 2

    # The current version of clavem.
    STRING = [MAJOR, MINOR, PATCH].compact.join(".")
  end
end
