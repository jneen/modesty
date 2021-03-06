module Modesty
  class Metric
    class Error < StandardError; end
  end

  module MetricMethods
    attr_writer :metrics

    def metrics
      @metrics ||= Hash.new do |h, k|
        raise Metric::Error, <<-msg.squish
          Unrecognized metric #{k.inspect}
        msg
      end
    end

    def metrics_starting_with(name)
      self.metrics.select{|k, v| k.to_s.starts_with?(name)}
    end

    def add_metric(metric)
      raise Metric::Error, <<-msg if self.metrics.include? metric.slug
        Metric #{metric.slug.inspect} already defined!
      msg
      self.metrics[metric.slug] = metric
    end

    def new_metric(slug, parent=nil, options={}, &block)
      if parent.is_a? Hash
        options=parent
      else
        options[:parent] = parent
      end

      metric = Metric.new(slug, options)
      yield Metric::Builder.new(metric) if block_given?
      add_metric(metric)
      metric
    end

    # Tracking
    def track!(name, *args)
      self.metrics[name.to_sym].track! *args
    rescue Modesty::Metric::Error
      # Fail silently in the event that a metric is not found.
    end
  end

  class API
    include MetricMethods
  end
end

require 'modesty/metric/base'
require 'modesty/metric/builder'
require 'modesty/metric/data'
