# logger.rb - logger methods
#
require "logger"

def setup_logger
  # Set up logger
  logger = Logger.new($stdout)
  logger_level = case ENV["LOGGER_LEVEL"].to_s.downcase
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
  logger.level = logger_level
  logger.info("Logger Level: #{logger_level}")

  logger
end
