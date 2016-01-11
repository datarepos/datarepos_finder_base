# $Id$
# $(c)$

module Datarepos
  class SeedUrl < ActiveRecord::Base
    scope :all_urls, -> {
      active
    }
    scope :active, -> {
      where(active: true)
    }
  end
end
