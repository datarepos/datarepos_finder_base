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
      end
    end

    delegate :format_validators, to: :class

    def perform
      return if ActiveRecord::Base.connection.table_exists? :fetched_urls

      ActiveRecord::Base.connection.create_table(
        :fetched_urls,
        temporary: true,
        options: 'engine=myisam'
      ) do |t|
        t.string :md5, length: 32, null: false
      end
      ActiveRecord::Base.connection.add_index :fetched_urls, :md5, unique: true

      SeedUrl.active.each do |seed|
        depth = (seed.url_max_depth || Settings.spider.max_depth)
        # puts "\n\n\n*** #{seed.uri} ***\n\n\n"
        spider(seed.uri, depth)
      end

      ActiveRecord::Base.connection.drop_table(:fetched_urls)
    end

    # class << self
    #   def fetch(url)
    #     (cmd = Getter::Uri.new(url: url)).call
    #     cmd.mech_page
    #   end
    # end

    def spider(url, depth)
      Spidr.start_at(url, {max_depth: depth}) do |spider|
        spider.every_page do |page|
          format_validators.each do |validator_klass|
            break if validate_format(validator_klass, page)
          end
        end
      end
    end

    private

    def validate_format(validator_klass, page)
      # puts "#{__FILE__}:#{__LINE__} here, page = #{page.inspect}"
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
      # puts "#{__FILE__}:#{__LINE__} NoMethodError  --  #{e.message}\n#{e.backtrace.join("\n")}"
      # invalid page
      false

    rescue RepoError::UnavailableUriError => e
      # puts "#{__FILE__}:#{__LINE__} RepoError::UnavailableUriError"
      # file was not available
      false

    rescue RepoError::IncompatibleProcessorError, RuntimeError => e
      # puts "#{__FILE__}:#{__LINE__} #{e.class.name}"
      # file was not compliant w format_validator
      false
    end



    def spider_link(lnk, url, depth)
      href = lnk.href
      root_href = URI.join(url,href).to_s
      # puts "#{__FILE__}:#{__LINE__} depth = #{depth}, href = #{href.inspect}, root_href = #{root_href}"
      spider(root_href, depth - 1)
      true

    rescue URI::InvalidURIError => e
      # puts "#{__FILE__}:#{__LINE__} here"
      false

    rescue ArgumentError => e
      # puts "#{__FILE__}:#{__LINE__} here"
      false
    end



    def agent
      @agent ||= Mechanize.new
    end
  end
end
