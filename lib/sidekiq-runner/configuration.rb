require 'yaml'

module SidekiqRunner
  class Configuration
    def self.default
      @default ||= Configuration.new
    end

    def self.get
      config = default.dup
      config.send :merge_config_file!
      config.send :sane?
      config
    end

    attr_accessor :configfile
    attr_accessor :bundle_env
    attr_accessor :daemonize
    attr_accessor :chdir
    attr_accessor :requirefile
    attr_accessor :verify_ps

    CONFIG_FILE_ATTRIBUTES = [ :pidfile, :logfile, :concurrency, :verbose ]
    CONFIG_FILE_ATTRIBUTES.each { |att| attr_accessor att }

    attr_reader   :queues

    def initialize
      @configfile  = File.join(Dir.pwd, 'config', 'sidekiq.yml')
      @bundle_env  = true
      @daemonize   = true
      @chdir       = nil
      @requirefile = nil
      @verify_ps   = false

      @pidfile     = File.join(Dir.pwd, 'tmp', 'pids', 'sidekiq.pid')
      @logfile     = File.join(Dir.pwd, 'log', 'sidekiq.log')
      @concurrency = 4
      @verbose     = false

      @queues      = []
    end

    def queue(name, weight = 1)
      @queues << [name, weight]
    end

    ['start', 'stop'].each do |action|
      ['success', 'error'].each do |state|
        attr_reader "#{action}_#{state}_cb".to_sym

        define_method("on_#{action}_#{state}") do |&block|
          instance_variable_set("@#{action}_#{state}_cb".to_sym, block)
        end
      end
    end

  private

    def merge_config_file!
      if File.exists?(configfile)
        yml = YAML.load_file(config_file)
        CONFIG_FILE_ATTRIBUTES.each do |k|
          v = yml[k] || yml[k.to_sym]
          self.send("#{k}=", v) if v
        end
      end

      self
    end

    def sane?
      raise 'No requirefile given and not in Rails env.' if !defined?(Rails) && !requirefile
      raise 'No queues given.' if queues.empty?
    end
  end
end
