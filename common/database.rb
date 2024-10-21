# database.rb - database related methods

def db_get_settings
  db_settings = {}

  db_settings['db_type'] = ENV['DB_TYPE']
  db_settings['db_user'] = ENV['DB_USER'].nil? ? "root" : ENV['DB_USER']
  db_settings['db_pass'] = ENV['DB_PASS'].nil? ? "" : ENV['DB_PASS']
  db_settings['db_host'] = ENV['DB_HOST'].nil? ? "localhost" : ENV['DB_HOST']
  db_settings['db_port'] = ENV['DB_PORT'].nil? ? "3306" : ENV['DB_PORT']
  db_settings['db_database'] = ENV['DB_DATABASE'].nil? ? "snowrabbit" : ENV['DB_DATABASE']
  db_settings['db_database_path'] = ENV['DB_DATABASE_PATH'].nil? ? "/var/lib/db" : ENV['DB_DATABASE_PATH']

  return db_settings
end


def db_connect
  db_settings = db_get_settings

  if db_settings['db_type'] == "sqlite"
    if db_settings['db_database_path'].to_s.empty?
      LOGGER.error("Error, DB_TYPE=sqlite but DB_DATABASE_PATH is not set, exiting!")
      exit 1
    end
    db_conn = Sequel.sqlite("#{db_settings['db_database_path']}/#{db_settings['db_database']}.db")
  elsif db_settings['db_type'] == "mysql"
    db_conn = Sequel.mysql2(db_settings['db_database'], user: db_settings['db_user'],
                                                        password: db_settings['db_pass'],
                                                        host: db_settings['db_host'],
                                                        port: db_settings['db_port'],
                                                        loggers: [Logger.new($stdout)]) # Temporary to log sql statements
  else
    LOGGER.error("Could not determine DB_TYPE, exiting!")
    exit 1
  end

  # Check to make sure schema is in the database
  db_add_schema(db_conn)

  return db_conn
end


def db_add_schema(db_conn)
  # Initialize databases
  unless db_conn.table_exists?(:ping_metrics)
    db_conn.create_table :ping_metrics do
      primary_key :id
      column :timestamp, DateTime
      column :source_site, String
      column :dest_site, String
      column :dest_ip, String
      column :transmitted, String
      column :received, String
      column :packet_loss, String
      column :min, String
      column :avg, String
      column :max, String
      index [ :source_site, :dest_site, :timestamp ]
    end
  end

  unless db_conn.table_exists?(:traceroute_metrics)
    db_conn.create_table :traceroute_metrics do
      primary_key :id
      column :timestamp, DateTime
      column :source_site, String
      column :dest_site, String
      column :dest_ip, String
      column :traceroute, String, text: true
      index [ :source_site, :dest_site, :timestamp ]
    end
  end

  unless db_conn.table_exists?(:probes)
    db_conn.create_table :probes do
      primary_key :id
      column :site, String
      column :ip, String
      column :description, String
      column :location, String
      column :location_lat, String
      column :location_long, String
      column :last_seen, Integer
      column :color, String
      column :secret, String
      column :active, Integer
    end
  end
end

