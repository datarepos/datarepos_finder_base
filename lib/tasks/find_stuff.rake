# $Id$
# $(c)$

namespace :jobs do
  task :find_stuff => :environment do
    Datarepos::FindStuff.new.perform
  end
end
