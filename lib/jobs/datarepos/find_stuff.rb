# $Id$
# $(c)$

require_relative '../../models/datarepos/repo.rb'
require_relative '../../models/datarepos/seed_url.rb'

module Datarepos
  class FindStuff < ActiveJob::Base
    attr_reader :agent

    class << self
      def format_validators
        Dir[Rails.root.join('**','validator','*.rb').to_s].each {|f| require f }

        base_val = Datarepos::Validator
        base_val.constants.select { |c| base_val.const_get(c).is_a?(Class) }
        .map{|k| Validator.const_get(k) }
      rescue NameError
        return []
      end
    end

    delegate :format_validators, to: :class

    def perform
      SeedUrl.active.each do |seed|
        depth = (seed.url_max_depth || 10)
        spider(seed.uri, depth)
      end
    end

    def spider(url, depth)
      require 'spidr'

      Spidr.start_at(url, max_depth: depth) do |spider|
        spider.every_url { |url| puts url }
        spider.every_page do |page|
          format_validators.each do |validator_klass|
            break if validate_format(validator_klass, page)
          end
        end
      end
    end

    private

    def validate_format(validator_klass, page)
      url = page.uri.to_s
      validator = validator_klass.new(page)
      validator.execute!

      raise RepoError::IncompatibleProcessorError.new unless validator.ok?

      # save repo here
      Repo.where(initial_uri: url).first_or_create.update!(
        name: File.basename(url, Pathname.new(url).extname),
        initial_uri: url,
        validated_format: validator_klass.name,
        last_validated: DateTime.now(),
        filesize: page["content-length"].to_i,
        columns: validator.validator.instance_variable_get(:@expected_columns),
        rows: validator.validator.data.length
      ) unless validator.try(:saved?)

      true

    rescue NoMethodError => e
      # invalid page
      false

    rescue RepoError::UnavailableUriError => e
      # file was not available
      false

    rescue RepoError::IncompatibleProcessorError, RuntimeError => e
      # file was not compliant w format_validator
      false
    end



    def spider_link(lnk, url, depth)
      href = lnk.href
      root_href = URI.join(url,href).to_s
      spider(root_href, depth - 1)
      true

    rescue URI::InvalidURIError => e
      false

    rescue ArgumentError => e
      false
    end
  end
end
