#!/usr/bin/env ruby

$stdout.sync = true
require "sinatra"
require "ostruct"
require "logger"
require "sqlite3"
require "mysql2"
require "sequel"
require "json"

require_relative "common/logger"
require_relative "common/database"

# Set sinatra config
set :bind, "0.0.0.0"
set :port, 4567

DB = db_connect

# Add auth for admin
helpers do
  def protected!
    return if authorized?
    headers["WWW-Authenticate"] = 'Basic realm="Restricted Area"'
    halt 401, "Not authorized\n"
  end

  def authorized?
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [ADMIN_USER, ADMIN_PASS]
  end
end

# Admin userpass
ADMIN_USER = ENV["ADMIN_USER"]
ADMIN_PASS = ENV["ADMIN_PASS"]

# Set up logger
LOGGER = setup_logger

# URL Actions
get "/" do
  redirect "/matrix"
end

get "/admin" do
  protected!
  erb :admin
end

get "/admin/metric_list" do
  protected!
  @ping_metrics = DB[:ping_metrics].limit(50).order(Sequel.desc(:timestamp))
  erb :admin_metric_list
end

get "/admin/probe_list" do
  protected!

  @probes = DB[:probes].where(active: 1)
  @probes_unregistered = DB[:probes].where(active: 2)
  @probes_inactive = DB[:probes].where(active: 0)
  @colors = ["maroon", "purple", "gunmetal", "lavender", "spanish-gray"]
  @locations = ["NA", "SA", "AF", "EU", "APAC", "AU"]

  erb :admin_probe_list
end

post "/admin/probe_update" do
  protected!
  puts "PROBE: #{params}"
  "OK"
end

post "/get_probes" do
  probes = DB[:probes].where(active: 1)
  probes_out = {}
  probes.each do |p|
    probes_out[p[:site]] = p[:ip]
  end

  JSON.generate(probes_out)
end

post "/register_probe" do
  # register probe
  # move active status from 2 to 1 and set a secret

  DB[:probes].where(site: params[:site]).update(secret: params[:secret], active: 1)
  "Probe registered"
end

get "/matrix" do
  # Get all of the latest ping times and display
  @begin_time = Time.now

  @probes_list = DB[:probes].where(active: 1).order(Sequel.desc(:location), Sequel.asc(:site)).all
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
    subquery = DB[:ping_metrics]
      .where(source_site: probe)
      .where(dest_site: active_probes - [probe])
      .select_group(:dest_site)
      .select_append { max(:timestamp).as(:latest_timestamp) }

    # Join the subquery with the original table to get the full row for the max timestamp
    latest_dest_probes = DB[:ping_metrics]
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

get "/site_details" do
  @begin_time = Time.now
  @source_site = params[:source_site]
  @dest_site = params[:dest_site]
  @ping_metrics = DB[:ping_metrics].where(source_site: @source_site, dest_site: @dest_site).order(Sequel.desc(:timestamp)).limit(5)
  traceroute_metrics = DB[:traceroute_metrics].where(source_site: @source_site, dest_site: @dest_site).order(Sequel.desc(:timestamp)).first

  @traceroute_out = if traceroute_metrics.nil?
    "No traceroute found."
  else
    traceroute_metrics
  end

  erb :site_details
end

get "/healthcheck" do
  "OK"
end

at_exit do
  DB.disconnect
end
