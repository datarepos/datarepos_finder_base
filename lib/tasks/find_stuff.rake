# $Id$
# $(c)$

namespace :jobs do
  task :find_stuff => :environment do
    DataRepos::FindStuff.new.perform
  end
end
