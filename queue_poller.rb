$:.unshift File.dirname(__FILE__)
require 'poller'
require 'pidder'

class QueuePoller
  attr_accessor :options, :pid_dir

  def execute(pid_dir)

    Signal.trap(:SIGTERM) { |signo|
      begin
        puts "Got kill signal: #{signo}, trying to kill child process with pid #{@forked_pid}"
        @forked_pid.nil? ? throw(:stop_polling) : Process.kill(0, @forked_pid)
        puts "Child process with pid #{@forked_pid} still running, waiting for child pid to finish"
        #@forked_pid ? (pid, status = Process.waitpid2(@forked_pid)): nil
        pid, status = Process.waitpid2(@forked_pid)
        puts "Child process with pid #{@forked_pid} finished with status #{status}, stopping polling"
        throw :stop_polling
      rescue Errno::ESRCH => e
        puts "Child process with pid #{@forked_pid} #{e}, stopping polling"
        throw :stop_polling
      end
    }
    #Process.kill("INT", 0)


    @pid_dir = pid_dir
    puts "Poller: Starting queue reader with parent pid #{Process.pid}"
    poller.start do |msg|
      begin
        puts "got message #{msg}"
        @record = parse_message(msg)
        puts "Poller: Starting to process record #{@record}"

        raise StandardError, "Process for #{@record} is currently running." if found_process?
        @forked_pid = Process.fork do
          sleep 30
        end
        puts "Poller: Started account creation with pid #{@forked_pid} for record #{@record}"
        write_pid_file(@forked_pid)

        pid, status = Process.waitpid2 @forked_pid
          puts status
        #publish_to_topic(pid, status)

      rescue StandardError => e
        puts "Poller: Error  \"#{e}\", processing #{@record}, adding it back to the queue."
        throw :skip_delete
      rescue => e
        puts "Poller: Error \"#{e}\", processing #{@record}, adding it back to the queue."
        throw :skip_delete
      end
    end
  end

  private
  def status_success?(status)
    status.exitstatus === 0 ? true : false
  end

  def proxy
    @proxy ||= ENV['ACCOUNT_PROXY_HOST']
  end

  def sqs_url
    @sqs_url ||= ENV['ACCOUNT_SQS_URL']
  end

  def aws_region
    @aws_region ||= ENV['AWS_REGION']
  end

  def http_proxy
    "http://#{proxy}:80"
  end

  def write_pid_file(pid)
    pidder.create_file pid
  end

  def found_process?
    pidder.check_running
  end

  def pidder
    Pidder.new(@record, pid_dir)
  end

  def poller
    @poller ||= Poller.new(sqs_options)
  end

  def publisher
    @publisher ||= Publisher.new(sns_options)
  end

  def account
    @account ||= Account.new(acct_creation_options)
  end

  def parse_message(msg)
    JSON.parse(msg.body)["Message"]
  end

  def sqs_options
    {
        :http_proxy => http_proxy,
        :region => aws_region,
        :sqs_url => sqs_url
    }
  end

  def sns_options
    {
        :http_proxy => http_proxy,
        :region => aws_region
    }
  end

  def acct_creation_options
    {
        :directory => File.expand_path("/app/account_creator/shared/data_files", File.dirname(__FILE__)),
        :log_level => :debug,
        :phone_number=> "858-215-8000",
        :headless => true,
        :record_id => @record
    }
  end
end

a = QueuePoller.new.execute('~/temp')
a