#!/usr/bin/env ruby

$stdout.sync = true
require 'sinatra'
require 'ostruct'
require 'logger'
require 'sqlite3'
require 'mysql2'
require 'sequel'
require 'json'

require_relative 'common/logger'
require_relative 'common/database'

# Set sinatra config
set :bind, '0.0.0.0'
set :port, 4567

# Set up logger
LOGGER = setup_logger


# URL Actions
get '/' do
  'Snowrabbit'
end

post '/pang' do
  # This will validate that a probe can reach the master and validates its secret
  # See if this probe is registered
  db_conn = db_connect

  begin
    probes_registered= db_conn[:probes].where(site: params[:site], active: 0..1)
    probes_unregistered = db_conn[:probes].where(site: params[:site], active: 2)

    # See if this site is registered or unregistered
    pang_authed = false
    probes_registered.each do |probe|
      if probe[:secret] == params[:secret]
        pang_authed = true
      end
    end

    # See if this probe is unregistered, if not mark it as unregistered
    if !pang_authed && (probes_registered.count == 0) && (probes_unregistered.count == 0)
      db_conn[:probes].insert(site: params[:site], ip: request.ip, active: 2)
    end

    if pang_authed
    # See if we need to update the IP address, sometimes it can be different
#    probe_ip = DB_CONNECTION[:probes].where(site: params[:site])
#    if probe_ip.first[:ip] != request.ip
#       LOGGER.info("Updating IP for site #{params[:site]} to #{request.ip}")
#       DB_CONNECTION[:probes].where(site: params[:site]).update(ip: request.ip)
#    end
      'OK'
    else
      status 401
       'Unauthorized'
    end
  ensure
    db_conn.disconnect
  end
end

get '/send_metric' do
  'Error, must POST to this endpoint'
end

post '/send_metric' do
  # Accepts a metric from a probe
  LOGGER.debug("Starting send_metric")
  db_conn = db_connect

  begin
    metric = OpenStruct.new

    metric.name = params[:name]
    metric.source_site = params[:source_site]
    metric.dest_site = params[:site]
    metric.ip = params[:ip]
    metric.timestamp = params[:time].to_i
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
    probe_secret = db_conn[:probes].where(site: metric.source_site, active: 1).first
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
        table = db_conn[:ping_metrics]
        table.insert(timestamp: Time.at(metric.timestamp),
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
        db_conn[:probes].where(site: metric.source_site).update(last_seen: Time.now().to_i)

        'OK'
      elsif metric.name == "traceroute"
        LOGGER.debug("Saving traceroute metric")
        table = db_conn[:traceroute_metrics]
        table.insert(timestamp: Time.at(metric.timestamp),
                     source_site: metric.source_site,
                     dest_site: metric.dest_site,
                     dest_ip: metric.ip,
                     traceroute: metric.traceroute)

        # Mark that we got a metric from this probe
        db_conn[:probes].where(site: metric.source_site).update(last_seen: Time.now().to_i)

        'OK'
      else
        status 401
        'Forbidden'
      end
    end
  ensure
    db_conn.disconnect
  end
end


post '/get_probes' do
  db_conn = db_connect
  begin
    probes = db_conn[:probes].where(active: 1)
    probes_out = {}
    probes.each do |p|
      probes_out[p[:site]] = p[:ip]
    end
    JSON.generate(probes_out)
  ensure
    db_conn.disconnect
  end
end


post '/register_probe' do
  # register probe
  # move active status from 2 to 1 and set a secret
  db_conn = db_connect
  begin
    db_conn[:probes].where(site: params[:site]).update(secret: params[:secret], active: 1)
    'Probe registered'
  ensure
    db_conn.disconnect
  end
end


get '/healthcheck' do
  'OK'
end

