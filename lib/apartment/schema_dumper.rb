module Apartment

  module SchemaDumper

    extend self

    def dump(database, schema = database)
      Database.process(database, :skip_persistent => true) do
        File.open(Rails.root.join("db", "schemas", schema + ".rb"), "w:utf-8") do |f|
          ActiveRecord::SchemaDumper.dump(ActiveRecord::Base.connection, f)
        end
      end
    end
  end

end
