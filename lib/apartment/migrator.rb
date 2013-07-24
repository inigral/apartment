module Apartment

  module Migrator

    extend self

    # Migrate to latest
    # TODO: remove the schema default values?
    def migrate(database, schema = "tenant")
      Database.process(database, :skip_persistent => true) do
        ActiveRecord::Migrator.migrate(migrations_path(schema), ENV["VERSION"] ? ENV["VERSION"].to_i : nil) do |migration|
          ENV["SCOPE"].blank? || (ENV["SCOPE"] == migration.scope)
        end
      end
    end

    # Migrate up/down to a specific version
    def run(direction, database, version, schema = "tenant")
      Database.process(database, :skip_persistent => true){ ActiveRecord::Migrator.run(direction, migrations_path(schema), version) }
    end

    # rollback latest migration `step` number of times
    def rollback(database, step = 1, schema = "tenant")
      Database.process(database, :skip_persistent => true){ ActiveRecord::Migrator.rollback(migrations_path(schema), step) }
    end

    def migrations_path(schema)
      [Rails.root.join("db", "migrate", schema)]
    end
  end

end
