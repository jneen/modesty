module Modesty
  class Metric
    class Builder
      def method_missing(name, *args)
        if Metric::ATTRIBUTES.include? name
          @metric.instance_variable_set("@#{name}", args[0])
        else
          super
        end
      end

      def initialize(metric)
        @metric = metric
      end

      def submetric(slug, &blk)
        Modesty.new_metric(@metric.slug/slug, @metric, &blk)
      end
    end

    class << self
      attr_writer :dir
      def dir
        @dir ||= File.join(
          Modesty::Experiment.dir,
          'metrics'
        )
      end
      
      def load_all!
        Dir.glob(
          File.join(self.dir, '**')
        ).each { |f| load f }
      end
    end


    ATTRIBUTES = [
      :description
    ]
    attr_reader *ATTRIBUTES
    attr_reader :slug
    attr_reader :parent

    #doctest: I can make a metric!
    # >> m = Modesty::Metric.new :foo
    # >> m.slug
    # => :foo
    def initialize(slug, parent=nil)
      @slug = slug
      @parent = parent
    end

  end

  class NoMetricError < NameError; end

  module MetricMethods
    attr_accessor :metrics

    #doctest: tools for adding new metrics
    # >> m = Modesty.new_metric(:foo) { |m| m.description "Foo" }
    # >> m.class
    # => Modesty::Metric
    # >> m.description
    # => "Foo"
    # >> Modesty.metrics.include? m
    # => true
    #
    #doctest: I can even call it without a block!
    # >> m = Modesty.new_metric :baz
    # >> m.slug
    # => :baz
    def add_metric(metric)
      @metrics ||= {}
      raise "Metric already defined!" if @metrics[metric.slug]
      @metrics[metric.slug] = metric
    end

    def new_metric(slug, parent=nil, &block)
      metric = Metric.new(slug, parent)
      yield Metric::Builder.new(metric) if block
      add_metric(metric)
      metric
    end

    #Tracking
    def track!(sym, count=1)
      if @metrics.include? sym
        @metrics[sym].track! count
      else
        raise NoMetricError
      end
    end
  end

  class << self
    include MetricMethods
  end
end