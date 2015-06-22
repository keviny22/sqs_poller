require 'aws-sdk'

class Poller
  attr_reader :options
  def initialize(options)
    @options = options
  end

  def start(&block)
    sqs_poller.poll(options = {}, &block)
  end

  private
  def sqs_client
    @sqs_client ||= Aws::SQS::Client.new(region: options[:region],
                                         http_proxy: options[:http_proxy])
  end

  def sqs_poller
    @sqs_poller ||= Aws::SQS::QueuePoller.new(options[:sqs_url],
                                              client: sqs_client)
  end
end