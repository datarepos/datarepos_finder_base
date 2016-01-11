require 'datarepos_finder_base'
require 'rails'
module DatareposFinderBase
  class Railtie < Rails::Railtie
    railtie_name :datarepos_finder_base

    rake_tasks do
      load "tasks/find_stuff.rake"
    end
  end
end
