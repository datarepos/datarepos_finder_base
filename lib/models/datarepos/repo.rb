# $Id: repo.rb 5 2015-11-02 19:07:47Z bmck $
# $(c): Copyright 2015 by datarepos.xyz $

module Datarepos
  class Repo < ActiveRecord::Base

    class TmpLocalCopy
      attr_reader :uri

      def initialize(uri)
        @uri = uri
      end

      def file
        @file ||= Tempfile.new(tmp_filename, tmp_folder, encoding: encoding).tap do |f|
          io.rewind
          f.write(io.read)
          f.close
        end
      end

      def io
        @io ||= uri.open
      end

      def encoding
        io.rewind
        io.read.encoding
      end

      def tmp_filename
        [
          Pathname.new(uri.path).basename,
          Pathname.new(uri.path).extname
        ]
      end

      def tmp_folder
        Rails.env.production? ? File.join('','tmp') : Rails.root.join('tmp')
      end
    end

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
    alias_method :save_csv_file, :save_file

    def csv_dataset
      stuff = TmpLocalCopy.new(initial_uri).file
      @csv_dataset ||= (validated_format.constantize).try(:to_csv, stuff.path)
    ensure
      stuff.close
      stuff.unlink
    end
  end
end
