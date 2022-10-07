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
  'Snowrabbit'
end

post '/pang' do
  # This will validate that a probe can reach the master and validates its secret
  # See if this probe is registered
  probes_registered= DB_CONNECTION[:probes].where(site: params[:site], active: 0..1)
  probes_unregistered = DB_CONNECTION[:probes].where(site: params[:site], active: 2)

  # See if this site is registered or unregistered
  pang_authed = false
  probes_registered.each do |probe|
    if probe[:secret] == params[:secret]
      pang_authed = true
    end
  end

  # See if this probe is unregistered, if not mark it as unregistered
  if !pang_authed && (probes_registered.count == 0) && (probes_unregistered.count == 0)
    DB_CONNECTION[:probes].insert(site: params[:site], ip: request.ip, active: 2)
  end

  if pang_authed
    # See if we need to update the IP address, sometimes it can be different
    probe_ip = DB_CONNECTION[:probes].where(site: params[:site])
    if probe_ip.first[:ip] != request.ip
       LOGGER.info("Updating IP for site #{params[:site]} to #{request.ip}")
       DB_CONNECTION[:probes].where(site: params[:site]).update(ip: request.ip)
    end

    'OK'
  else
    status 401
     'Unauthorized'
  end
end

get '/send_metric' do
  'Error, must POST to this endpoint'
end

post '/send_metric' do
  # Accepts a metric from a probe
  LOGGER.debug("Starting send_metric")
  metric = OpenStruct.new

  metric.name = params[:name]
  metric.source_site = params[:source_site]
  metric.dest_site = params[:site]
  metric.ip = params[:ip]
  metric.timestamp = params[:time]
  metric.secret = params[:secret]

  if metric.name == "ping"
    metric.transmitted = params[:transmitted]
    metric.received = params[:received]
    metric.packet_loss = params[:packet_loss]
    metric.min = params[:min]
    metric.avg = params[:avg]
    metric.max = params[:max]
  elsif metric.name = "traceroute"
    metric.traceroute = params[:traceroute]
  end

  # Let's make sure we have the correct secret
  probe_secret = DB_CONNECTION[:probes].where(site: metric.source_site, active: 1).first
  if !probe_secret
    LOGGER.debug("No secret found for site #{metric.source_site}")
    status 401
    'Forbidden'   
  elsif (metric.secret != probe_secret[:secret])
    LOGGER.debug("secret failed, ignoring...")
    status 401
    'Forbidden'
  elsif metric.secret == probe_secret[:secret]
    LOGGER.debug("secret succeeded, continuing")
    LOGGER.debug("VALUE: #{metric}")

    if metric.name == "ping"
      LOGGER.debug("Saving ping metric")
      table = DB_CONNECTION[:ping_metrics]
      table.insert(timestamp: metric.timestamp,
                   source_site: metric.source_site,
                   dest_site: metric.dest_site,
                   dest_ip: metric.ip,
                   transmitted: metric.transmitted,
                   received: metric.received,
                   packet_loss: metric.packet_loss,
                   min: metric.min,
                   avg: metric.avg,
                   max: metric.max)

      # Mark that we got a metric from this probe
      DB_CONNECTION[:probes].where(site: metric.source_site).update(last_seen: Time.now().to_i)

      'OK'
    elsif metric.name == "traceroute"
      LOGGER.debug("Saving traceroute metric")
      table = DB_CONNECTION[:traceroute_metrics]
      table.insert(timestamp: metric.timestamp,
                   source_site: metric.source_site,
                   dest_site: metric.dest_site,
                   dest_ip: metric.ip,
                   traceroute: metric.traceroute)

      # Mark that we got a metric from this probe
      DB_CONNECTION[:probes].where(site: metric.source_site).update(last_seen: Time.now().to_i)

      'OK'
    else
      status 401
      'Forbidden'
    end

  end
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


get '/healthcheck' do
  'OK'
end

