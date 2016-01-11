# $Id: repo.rb 5 2015-11-02 19:07:47Z bmck $
# $(c): Copyright 2015 by datarepos.xyz $

module Datarepos
  class Repo < ActiveRecord::Base
    include Datarepos::LocalizedVersion
    # serialize :command_set

    # attr_writer :cmd_set
    # attr_reader :commands

    validates :name, presence: true
    validates :initial_uri, presence: true
    validates :validated_format, presence: true

    scope :all_repos, -> {
      active
    }
    scope :active, -> {
      where(active: true)
    }
    scope :contains, -> x {
      where(x.split.map { |xx| " locate(\"#{xx.downcase}\", lower(name)) > 0 " }.join(' and '))
    }

    def name
      @name ||= (initial_uri.nil? ? '' :
                 File.basename(initial_uri).gsub(/#{File.extname(initial_uri)}$/,''))
    end

    def size
      filesize ? number_to_human_size(filesize).gsub(/(Bytes?|B$)/,'') : nil
    end

    def destroy
      self.active = false
      save!
    end

    def save_file(fn)
      IO.binwrite(fn, csv_dataset)
    end

    alias_method :fetch, :save_file

    def csv_dataset
      stuff = FindStuff.fetch(initial_uri)
      @csv_dataset ||= (validated_format.constantize).try(:to_csv, stuff)
    end
  end
end
