# $Id$
# $(c)$

module Datarepos
  module LocalizedVersion
    extend ActiveSupport::Concern

    included do
      class_eval do
        attr_reader :remote_uri, :io
      end
    end

    def process_local_file(mech_page, local_extname, bin, &block)
      open(remote_uri  = mech_page.uri) do |io_ref|
        enc = io_ref.read.encoding
        io_ref.rewind
        Tempfile.new(['tmprepos', local_extname], tmp_folder, encoding: enc).tap do |f|
          f.binmode if bin
          f.write(io_ref.read.gsub(/\r\n?/, "\n"))
          yield(f)
          f.close
        end
      end
    rescue OpenURI::HTTPError, Errno::ETIMEDOUT, SocketError => e
      sleep 5
      retry
    end

    def encoding
      io.rewind
      io.read.encoding
    end

    module ClassMethods
      def tmp_folder
        Rails.env.production? ? File.join('', 'tmp') : Rails.root.join('tmp')
      end
    end

    def tmp_folder
      Rails.env.production? ? File.join('', 'tmp') : Rails.root.join('tmp')
    end
  end
end
