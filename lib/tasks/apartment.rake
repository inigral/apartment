# TODO(GC): what about these & other unsupported default rails db rake tasks:
# Rake::Task["db:fixtures:load"]
# Rake::Task["db:migrate:status"]
# Rake::Task["db:schema:load"]
# Rake::Task["db:structure:dump"]
# Rake::Task["db:version"]

namespace :db do
  task(:migrate).clear
  task :migrate => 'apartment:migrate'
  task(:rollback).clear
  task :rollback => 'apartment:rollback'
  task(:setup).clear
  task :setup => 'apartment:setup'
  task(:seed).clear
  task :seed => 'apartment:seed'
  namespace :schema do
    task(:dump).clear
    task :dump => 'apartment:schema:dump'
  end
end

apartment_namespace = namespace :apartment do

  task :create => ['db:create', :environment] do
    # TODO: also create all non-public non-tenant schemas

    Apartment.database_names.each do |db|
      Apartment::Database.create(db, :skip_schema_import => true)
    end
  end

  task :setup => ['db:create', :environment] do
    Apartment::Database.import_database_schema "public"
    Apartment::Database.seed "public" if Apartment.seed_after_create

    # TODO: also create all other non-public non-tenant schemas. pass :schema for seeding

    Apartment.database_names.each do |db|
      Apartment::Database.create(db, schema: "tenant")
    end
  end

  desc "Migrate all multi-tenant databases"
  task :migrate => :environment do
    # TODO: also migrate all other non-tenant schemas
    ["public"].each do |db|
      puts("Migrating #{db} database")
      Apartment::Migrator.migrate db, db
    end

    Apartment.database_names.each do |db|
      puts("Migrating #{db} database")
      Apartment::Migrator.migrate db, "tenant"
    end

    apartment_namespace['schema:dump'].invoke
  end

  desc "Seed all multi-tenant databases"
  task :seed => :environment do
    # TODO: also seed all other non-tenant schemas
    ["public"].each do |db|
      puts("Seeding #{db} database")
      Apartment::Database.process(db) do
        Apartment::Database.seed "public"
      end
    end

    Apartment.database_names.each do |db|
      puts("Seeding #{db} database")
      Apartment::Database.process(db) do
        Apartment::Database.seed "tenant"
      end
    end
  end

  desc "Rolls the schema back to the previous version (specify steps w/ STEP=n) across all multi-tenant dbs."
  task :rollback => 'db:rollback' do
    step = ENV['STEP'] ? ENV['STEP'].to_i : 1

    Apartment.database_names.each do |db|
      puts("Rolling back #{db} database")
      Apartment::Migrator.rollback db, step
    end
  end

  namespace :migrate do

    desc 'Runs the "up" for a given migration VERSION across all multi-tenant dbs.'
    task :up => 'db:migrate:up' do
      version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
      raise 'VERSION is required' unless version

      Apartment.database_names.each do |db|
        puts("Migrating #{db} database up")
        Apartment::Migrator.run :up, db, version
      end
    end

    desc 'Runs the "down" for a given migration VERSION across all multi-tenant dbs.'
    task :down => 'db:migrate:down' do
      version = ENV['VERSION'] ? ENV['VERSION'].to_i : nil
      raise 'VERSION is required' unless version

      Apartment.database_names.each do |db|
        puts("Migrating #{db} database down")
        Apartment::Migrator.run :down, db, version
      end
    end

    desc  'Rollbacks the database one migration and re migrate up (options: STEP=x, VERSION=x).'
    task :redo => 'db:migrate:redo' do
      if ENV['VERSION']
        apartment_namespace['migrate:down'].invoke
        apartment_namespace['migrate:up'].invoke
      else
        apartment_namespace['rollback'].invoke
        apartment_namespace['migrate'].invoke
      end
    end

  end

  namespace :schema do

    task :dump => :environment do
      FileUtils.mkdir_p "#{Rails.root}/db/schemas"

      # TODO: also dump all other non-tenant schemas
      ["public"].each do |db|
        puts("Dumping #{db} database")
        Apartment::SchemaDumper.dump db, db
      end

      db = Apartment.database_names.first
      puts("Dumping tenant database (based on #{db})")
      Apartment::SchemaDumper.dump db, "tenant"
    end

  end
end
