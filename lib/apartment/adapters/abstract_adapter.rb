require 'active_record'

module Apartment
  module Adapters
    class AbstractAdapter

      #   @constructor
      #   @param {Hash} config Database config
      #
      def initialize(config)
        @config = config
      end

      #   Create a new database, import schema, seed if appropriate
      #
      #   @param {String} database Database name
      #
      def create(database, options = {})
        create_database(database)

        process(database, :skip_persistent => true) do
          import_database_schema(options[:schema]) unless options[:skip_schema_import]

          # Seed data if appropriate
          seed_data(options[:schema]) if Apartment.seed_after_create

          yield if block_given?
        end
      end

      #   Get the current database name
      #
      #   @return {String} current database name
      #
      def current_database
        Apartment.connection.current_database
      end

      #   Note alias_method here doesn't work with inheritence apparently ??
      #
      def current
        current_database
      end

      #   Drop the database
      #
      #   @param {String} database Database name
      #
      def drop(database)
        # Apartment.connection.drop_database   note that drop_database will not throw an exception, so manually execute
        Apartment.connection.execute("DROP DATABASE #{environmentify(database)}" )

      rescue *rescuable_exceptions
        raise DatabaseNotFound, "The database #{environmentify(database)} cannot be found"
      end

      #   Connect to db, do your biz, switch back to previous db
      #
      #   @param {String?} database Database or schema to connect to
      #
      def process(database = nil, options = {})
        current_db = current_database
        switch(database, options)
        yield if block_given?

      ensure
        switch(current_db) rescue reset
      end

      #   Establish a new connection for each specific excluded model
      #
      def process_excluded_models
        # All other models will shared a connection (at Apartment.connection_class) and we can modify at will
        Apartment.excluded_models.each do |excluded_model|
          excluded_model.constantize.establish_connection @config
        end
      end

      #   Reset the database connection to the default
      #
      def reset
        Apartment.establish_connection @config
      end

      #   Switch to new connection (or schema if appopriate)
      #
      #   @param {String} database Database name
      #
      def switch(database = nil, options = {})
        # Just connect to default db and return
        return reset if database.nil?

        connect_to_new(database, options)
      end

      #   Load the rails seed file into the db
      #
      def seed_data(schema)
        puts "Seeding #{current_database} with #{schema}"
        silence_stream(STDOUT){ load_or_abort("#{Rails.root}/db/seeds/#{schema}.rb") } # Don't log the output of seeding the db
      end
      alias_method :seed, :seed_data

      #   Import the database schema
      #
      def import_database_schema(schema)
        ActiveRecord::Schema.verbose = false    # do not log schema load output.

        ActiveRecord::Migrator.migrations_path = Apartment::Migrator.migrations_path(schema)

        load_or_abort(Apartment.schema_file(schema))
      end

    protected

      #   Create the database
      #
      #   @param {String} database Database name
      #
      def create_database(database)
        Apartment.connection.create_database( environmentify(database) )

      rescue *rescuable_exceptions
        raise DatabaseExists, "The database #{environmentify(database)} already exists."
      end

      #   Connect to new database
      #
      #   @param {String} database Database name
      #
      def connect_to_new(database)
        Apartment.establish_connection multi_tenantify(database)
        Apartment.connection.active?   # call active? to manually check if this connection is valid

      rescue *rescuable_exceptions
        raise DatabaseNotFound, "The database #{environmentify(database)} cannot be found."
      end

      #   Prepend the environment if configured and the environment isn't already there
      #
      #   @param {String} database Database name
      #   @return {String} database name with Rails environment *optionally* prepended
      #
      def environmentify(database)
        unless database.include?(Rails.env)
          if Apartment.prepend_environment
            "#{Rails.env}_#{database}"
          elsif Apartment.append_environment
            "#{database}_#{Rails.env}"
          else
            database
          end
        else
          database
        end
      end

      #   Return a new config that is multi-tenanted
      #
      def multi_tenantify(database)
        @config.clone.tap do |config|
          config[:database] = environmentify(database)
        end
      end

      #   Load a file or abort if it doesn't exists
      #
      def load_or_abort(file)
        if File.exists?(file)
          load(file)
        else
          abort %{#{file} doesn't exist yet}
        end
      end

      #   Exceptions to rescue from on db operations
      #
      def rescuable_exceptions
        [ActiveRecord::StatementInvalid] + [rescue_from].flatten
      end

      #   Extra exceptions to rescue from
      #
      def rescue_from
        []
      end
    end
  end
end