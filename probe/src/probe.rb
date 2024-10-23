#!/usr/bin/env ruby

# This script runs once every few mins and pings all probe nodes
$stdout.sync = true
require "net/ping"
require "net/http"
require "logger"
require "mixlib/shellout"
require "ostruct"
require "json"

require_relative "common/logger"

# Set up logger
LOGGER = setup_logger

PROBE_SITE = ENV["PROBE_SITE"]
CONTROLLER_HOST = ENV["CONTROLLER_HOST"]
CONTROLLER_PORT = ENV["CONTROLLER_PORT"]
PROBE_SECRET = ENV["PROBE_SECRET"]
PROBE_INTERVAL = (ENV["PROBE_INTERVAL"].to_i > 0) ? ENV["PROBE_INTERVAL"].to_i : 60
PROBE_USE_SSL = !ENV["PROBE_USE_SSL"].to_s.empty?

def get_url
  url = "http://#{CONTROLLER_HOST}"
  if PROBE_USE_SSL
    url = "https://#{CONTROLLER_HOST}"
  end

  if CONTROLLER_PORT
    url += ":#{CONTROLLER_PORT}"
  end

  url
end

def send_pang
  uri = URI("#{get_url}/pang")

  begin
    res = Net::HTTP.post_form(uri, "name" => "pang",
      "site" => PROBE_SITE,
      "secret" => PROBE_SECRET)

    if res.code == "200"
      return true
    end

    false
  rescue => e
    LOGGER.error("send_pang timed out - #{e.message}")
    false
  end
end

def get_probe_sites
  uri = URI("#{get_url}/get_probes")
  probe_sites = {}

  begin
    res = Net::HTTP.post_form(uri, "secret" => PROBE_SECRET)

    probe_sites = JSON.parse(res.body)
  rescue
    LOGGER.error("get_probe_sites timed out")
  end

  probe_sites
end

def send_ping_metric(ping_vals)
  LOGGER.debug("Sending ping metric")
  LOGGER.debug("METRIC: #{ping_vals}")
  uri = URI("#{get_url}/send_metric")

  begin
    res = Net::HTTP.post_form(uri, "name" => "ping",
      "source_site" => PROBE_SITE,
      "site" => ping_vals.site,
      "ip" => ping_vals.ip,
      "transmitted" => ping_vals.transmitted,
      "received" => ping_vals.received,
      "packet_loss" => ping_vals.packet_loss,
      "min" => ping_vals.min,
      "avg" => ping_vals.avg,
      "max" => ping_vals.max,
      "mdev" => ping_vals.mdev,
      "time" => Time.now.to_i,
      "secret" => PROBE_SECRET)
    LOGGER.debug("Result body: #{res.body}")
  rescue => e
    LOGGER.error("send_ping_metric errored out - #{e.inspect}")
  end
end

def send_traceroute_metric(site, ip, traceroute_out)
  LOGGER.info("Sending traceroute metric")
  uri = URI("#{get_url}/send_metric")
  LOGGER.debug("URL: #{uri}")

  begin
    res = Net::HTTP.post_form(uri, "name" => "traceroute",
      "source_site" => PROBE_SITE,
      "site" => site,
      "ip" => ip,
      "traceroute" => traceroute_out,
      "time" => Time.now.to_i,
      "secret" => PROBE_SECRET)

    LOGGER.debug("Result body: #{res.body}")
  rescue => e
    LOGGER.error("send_traceroute_metric errored out - #{e.inspect}")
  end
end

# Make sure required vars are set
if CONTROLLER_HOST.nil? || CONTROLLER_HOST.empty?
  puts "ERROR, CONTROLLER_HOST is not set! Exiting..."
  exit 1
end

loop do
  # Send pang to controller along with secret
  LOGGER.info("Sending pang")
  if !send_pang
    LOGGER.info("Error, cannot reach controller or secret failed!")
  else
    # We got a pung back, let's get all sites

    # Parse returned json from controller
    probe_sites = get_probe_sites

    # Let's loop through the sites and ping ips
    probe_sites.each do |site, ip|
      unless site == PROBE_SITE
        LOGGER.info("Pinging #{site} - #{ip}")

        ping_cmd = "ping -c 5 -i 1 #{ip}"
        ping = Mixlib::ShellOut.new(ping_cmd)
        ping.run_command

        # Parse out the output
        ping_out = OpenStruct.new
        ping_out.site = site
        ping_out.ip = ip

        ping.stdout.each_line do |line|
          line.chomp!
          if line.include?("packet loss")
            /^(\d+) packets transmitted, (\d+) packets received, ([0-9\.\-\/]+)% packet loss/ =~ line
            ping_out.transmitted = $1
            ping_out.received = $2
            ping_out.packet_loss = $3
          elsif line.start_with?("round-trip")
            /^round-trip min\/avg\/max = ([0-9\.\-\/]+)\/([0-9\.\-\/]+)\/([0-9\.\-\/]+) ms$/ =~ line
            ping_out.min = $1
            ping_out.avg = $2
            ping_out.max = $3
          end
        end

        send_ping_metric(ping_out)

        LOGGER.info("Tracerouting #{site} - #{ip}")
        traceroute_cmd = "traceroute -n -w 1 #{ip}"
        traceroute = Mixlib::ShellOut.new(traceroute_cmd)
        traceroute.run_command
        send_traceroute_metric(site, ip, traceroute.stdout)
        LOGGER.debug("OUT: #{traceroute.stdout}")

      end
    end
  end
  # Sleep for a bit before checking again
  LOGGER.info("Sleeping for #{PROBE_INTERVAL}")
  sleep(PROBE_INTERVAL)
end
