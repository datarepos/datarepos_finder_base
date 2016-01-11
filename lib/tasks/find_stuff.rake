# $Id$
# $(c)$

namespace :jobs do
  task :find_stuff => :environment do
    FindStuff.new.perform
  end
end
