# $Id$
# $(c)$

require 'open-uri'

module DatareposFinderBase
  require 'datarepos_finder_base/railtie' if defined?(Rails)

  require_relative 'datarepos_finder_base/version.rb'

  require_relative 'jobs/datarepos/find_stuff.rb'
  require_relative 'models/datarepos/repo.rb'
  require_relative 'models/datarepos/seed_url.rb'
end
