# encoding: utf-8
#
# This file is part of the clavem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "bundler/setup"

if ENV["COVERAGE"]
  require "simplecov"
  require "coveralls"

  Coveralls.wear! if ENV["CI"]

  SimpleCov.start do
    root = Pathname.new(File.dirname(__FILE__)) + ".."

    add_filter do |src_file|
      path = Pathname.new(src_file.filename).relative_path_from(root).to_s
      path !~ /^lib/
    end
  end
end

require "i18n"
::I18n.enforce_available_locales = false
require File.dirname(__FILE__) + "/../lib/clavem"
Lazier::I18n.default_locale = :en