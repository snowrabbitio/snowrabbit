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
LOGGER_LEVEL = ENV['LOGGER_LEVEL'].nil? ? "info" : ENV['LOGGER_LEVEL']
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

  DB_CONNECTION = Sequel.mysql2(DB_DATABASE, user: DB_USER,  password: DB_PASS, host: DB_HOST, port: DB_PORT)
else
  LOGGER.error("Could not determine DB_TYPE, exiting!")
  exit 1
end

# Initialize databases
unless DB_CONNECTION.table_exists?(:ping_metrics)
  DB_CONNECTION.create_table :ping_metrics do
    primary_key :id
    column :timestamp, Integer
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
    column :timestamp, Integer
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
  @locations = ['US', 'EU', 'APAC']

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
  @probes_list = DB_CONNECTION[:probes].where(active: 1).order(Sequel.desc(:location), Sequel.asc(:site))
  if @probes_list.count > 0
    @probe_last_seen = @probes_list.order(Sequel.desc(:last_seen)).first[:last_seen]
  end 

  # Get the number of probes * 5 and double it just to be safe, i don't think we'll need more than that
  @ping_table = DB_CONNECTION[:ping_metrics].limit(@probes_list.count * 5 * 2).order(Sequel.desc(:timestamp))

  erb :matrix
end


get '/site_details' do
  @begin_time = Time.now
  @source_site = params[:source_site]
  @dest_site = params[:dest_site]
  @ping_metrics = DB_CONNECTION[:ping_metrics].where(source_site: @source_site, dest_site: @dest_site).limit(5).order(Sequel.desc(:timestamp))
  traceroute_metrics = DB_CONNECTION[:traceroute_metrics].where(source_site: @source_site, dest_site: @dest_site).limit(1).order(Sequel.desc(:timestamp))

  if traceroute_metrics.count > 0
    @traceroute_out = traceroute_metrics.first
  else
    @traceroute_out = "No traceroute found."
  end

  erb :site_details
end

get '/healthcheck' do
  'OK'
end

