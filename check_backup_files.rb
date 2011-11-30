require 'rubygems'
require 'fog'
require 'pit'
require 'yaml'
require 'active_support/all'
require 'colorize'

class AwsConnect
  @@pit = Pit.get('s3', :require => { 'access_key' => '', 'secret_key' => ''})

  def self.run(opt = {})
    self.new(opt).run
  end

  def initialize(opt = {})
    @access_key   = opt[:access_key] || @@pit['access_key']
    @secret_key   = opt[:secret_key] || @@pit['secret_key']
    @region       = opt[:region] || 'ap-northeast-1'
  end

  def connect
    Fog::Storage.new(:provider => 'AWS',
                     :aws_access_key_id       => @access_key,
                     :aws_secret_access_key   => @secret_key,
                     :region                  => @region )
  end
end

class CheckBackupFiles
  def self.run
    self.new.run
  end

  def run
    yaml = load_yaml
    yaml["target_apps"].each do |app_name, config|
      puts "Application : #{app_name}".on_yellow
      aws = AwsConnect.new(:region => config["region"])
      connection = aws.connect
      config["backups"].keys.each do |path|
        files = connection.directories.get(config["bucket"]).files.select{|file| file.key.include?(config["backups"]["#{path}"]) }
        file = select_latest_file files

        created_at = Time.parse(file.last_modified.to_s)

        puts "\tFile    : #{file.key}"
        puts "\tCreated : #{created_at.strftime('%Y/%m/%d %H:%M:%S')}".colorize(:color => risk_color(created_at))
        puts "\tCount   : #{files.count - 1}"
        puts ""
      end
    end
  end

  def load_yaml
    YAML.load_file("./config.yml")
  end

  def select_latest_file files
    files.sort{|x,y| y.last_modified <=> x.last_modified}.first
  end

  def risk_color created_at
    created_at + 1.day > Time.now ? :green : :red
  end
end

CheckBackupFiles.run
