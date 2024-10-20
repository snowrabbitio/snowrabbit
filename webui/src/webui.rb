#!/usr/bin/env ruby

$stdout.sync = true
require 'sinatra'
require 'ostruct'
require 'logger'
require 'sqlite3'
require 'mysql2'
require 'sequel'
require 'json'

# Set sinatra config
set :bind, '0.0.0.0'
set :port, 4567

# Add auth for admin
helpers do
  def protected!
    return if authorized?
    headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [ADMIN_USER, ADMIN_PASS]
  end
end

# Admin userpass
ADMIN_USER = ENV['ADMIN_USER']
ADMIN_PASS = ENV['ADMIN_PASS']

# Set up logger
LOGGER = Logger.new(STDOUT)
LOGGER_LEVEL = case ENV['LOGGER_LEVEL'].to_s.downcase
            when "debug"
              Logger::DEBUG
            when "info"
              Logger::INFO
            when "warn"
              Logger::WARN
            when "error"
              Logger::ERROR
            when "fatal"
              Logger::FATAL
            else
              Logger::INFO
            end

# Set the logger level
LOGGER.level = LOGGER_LEVEL
LOGGER.info("Logger Level: #{LOGGER_LEVEL}")

# Set up database connection
DB_TYPE = ENV['DB_TYPE']
DB_USER = ENV['DB_USER'].nil? ? "root" : ENV['DB_USER']
DB_PASS = ENV['DB_PASS'].nil? ? "" : ENV['DB_PASS']
DB_HOST = ENV['DB_HOST'].nil? ? "localhost" : ENV['DB_HOST']
DB_PORT = ENV['DB_PORT'].nil? ? "3306" : ENV['DB_PORT']
DB_DATABASE = ENV['DB_DATABASE'].nil? ? "snowrabbit" : ENV['DB_DATABASE']
DB_DATABASE_PATH = ENV['DB_DATABASE_PATH'].nil? ? "/var/lib/db" : ENV['DB_DATABASE_PATH']

if DB_TYPE == "sqlite"
  if DB_DATABASE_PATH.nil?
    LOGGER.error("Error, DB_TYPE=sqlite but DB_DATABASE_PATH is not set, exiting!")
    exit 1
  end
  DB_CONNECTION = Sequel.sqlite("#{DB_DATABASE_PATH}/#{DB_DATABASE}.db")
elsif DB_TYPE == "mysql"
  if LOGGER_LEVEL == "debug"
    LOGGER.debug("Mysql DB Settings")
    LOGGER.debug("-----------------")
    LOGGER.debug("DB_USER: #{DB_USER}")
    LOGGER.debug("DB_HOST: #{DB_HOST}")
    LOGGER.debug("DB_PORT: #{DB_PORT}")
    LOGGER.debug("DB_DATABASE: #{DB_DATABASE}")
  end

  DB_CONNECTION = Sequel.mysql2(DB_DATABASE, user: DB_USER,  password: DB_PASS, host: DB_HOST, port: DB_PORT, loggers: [Logger.new($stdout)])
else
  LOGGER.error("Could not determine DB_TYPE, exiting!")
  exit 1
end

# Initialize databases
unless DB_CONNECTION.table_exists?(:ping_metrics)
  DB_CONNECTION.create_table :ping_metrics do
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

unless DB_CONNECTION.table_exists?(:traceroute_metrics)
  DB_CONNECTION.create_table :traceroute_metrics do
    primary_key :id
    column :timestamp, DateTime
    column :source_site, String
    column :dest_site, String
    column :dest_ip, String
    column :traceroute, String, text: true
    index [ :source_site, :dest_site, :timestamp ]
  end
end

unless DB_CONNECTION.table_exists?(:probes)
  DB_CONNECTION.create_table :probes do
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


# URL Actions
get '/' do
  redirect '/matrix'
end


get '/admin' do
  protected!
  erb :admin
end


get '/admin/metric_list' do
  protected!
  @ping_metrics = DB_CONNECTION[:ping_metrics].limit(50).order(Sequel.desc(:timestamp)) 
  erb :admin_metric_list
end


get '/admin/probe_list' do
  protected!
  @probes = DB_CONNECTION[:probes].where(active: 1)
  @probes_unregistered = DB_CONNECTION[:probes].where(active: 2)
  @probes_inactive = DB_CONNECTION[:probes].where(active: 0)
  @colors = ['maroon', 'purple', 'gunmetal', 'lavender', 'spanish-gray']
  @locations = ['US', 'EU', 'APAC', 'AU']

  erb :admin_probe_list
end


post '/admin/probe_update' do
  protected!
  puts "PROBE: #{params}"
  'OK'
end


post '/get_probes' do
  probes = DB_CONNECTION[:probes].where(active: 1)
  probes_out = {}
  probes.each do |p|
    probes_out[p[:site]] = p[:ip]
  end
  JSON.generate(probes_out)
end


post '/register_probe' do
  # register probe
  # move active status from 2 to 1 and set a secret
  site = params[:site]
  secret = params[:secret]

  DB_CONNECTION[:probes].where(site: site).update(secret: secret, active: 1)

  'Probe registered'
end


get '/matrix' do
  # Get all of the latest ping times and display
  @begin_time = Time.now

  @probes_list = DB_CONNECTION[:probes].where(active: 1).order(Sequel.desc(:location), Sequel.asc(:site)).all
  if @probes_list.count > 0
    @probe_last_seen = 0
    active_probes = []
    @probes_list.each do |probe|
      # Get the most recent last seen
      if probe[:last_seen] > @probe_last_seen
        @probe_last_seen = probe[:last_seen]
      end

      # Array of active probes
      active_probes << probe[:site]
    end
  end

  @ping_metrics = {}
  active_probes.each do |probe|
    # Get latest result from each site
    subquery = DB_CONNECTION[:ping_metrics]
               .where(source_site: probe)
               .where(dest_site: active_probes - [probe])
               .select_group(:dest_site)
               .select_append{ max(:timestamp).as(:latest_timestamp) }

    # Join the subquery with the original table to get the full row for the max timestamp
    latest_dest_probes = DB_CONNECTION[:ping_metrics]
                         .join(subquery, {
                           Sequel[:ping_metrics][:dest_site] => Sequel[:t1][:dest_site],  # Join on dest_site
                           Sequel[:ping_metrics][:timestamp] => Sequel[:t1][:latest_timestamp]  # Join on max timestamp
                         }, table_alias: :t1)
                         .select(Sequel[:ping_metrics][:dest_site], Sequel[:ping_metrics][:avg], Sequel[:ping_metrics][:timestamp])

    # Convert results to hash keyed by site
    @ping_metrics[probe] = latest_dest_probes.all.each_with_object({}) do |row, hash|
      hash[row[:dest_site]] = {
        avg: row[:avg],
        timestamp: row[:timestamp]
      }
    end
  end

  erb :matrix
end


get '/site_details' do
  @begin_time = Time.now
  @source_site = params[:source_site]
  @dest_site = params[:dest_site]
  @ping_metrics = DB_CONNECTION[:ping_metrics].where(source_site: @source_site, dest_site: @dest_site).order(Sequel.desc(:timestamp)).limit(5)
  traceroute_metrics = DB_CONNECTION[:traceroute_metrics].where(source_site: @source_site, dest_site: @dest_site).order(Sequel.desc(:timestamp)).first

  if traceroute_metrics.nil?
    @traceroute_out = "No traceroute found."
  else
    @traceroute_out = traceroute_metrics
  end

  erb :site_details
end

get '/healthcheck' do
  'OK'
end

