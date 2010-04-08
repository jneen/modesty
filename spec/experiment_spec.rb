require 'modesty'

describe Modesty::Experiment, "creating an experiment" do
  before :all do
    Modesty.metrics = {}
    Modesty.new_metric :foo do |m|
      m.description "Foo"
      m.submetric :bar do |m|
        m.description "Bar"
      end
    end

    Modesty.new_metric :baz do |m|
      m.description "Baz"
    end
  end

  it "can create an experiment with a block" do
    e = Modesty.new_experiment(:creation_page) do |m|
      m.description "Three versions of the creation page"
      m.alternatives :heavyweight, :middleweight, :lightweight
      m.metrics :foo/:bar, :baz
    end 

    Modesty.experiments.should include :creation_page
    Modesty.experiments[:creation_page].should == e

    e.metrics.should include Modesty.metrics[:foo/:bar]
    e.metrics.should include Modesty.metrics[:baz]
    e.alternatives.should == [:heavyweight, :middleweight, :lightweight]
    e.description.should == "Three versions of the creation page"
  end

  it "auto-creates metrics" do
    Modesty.metrics.should include :foo/:bar/:creation_page/:heavyweight
    Modesty.metrics.should include :foo/:bar/:creation_page/:middleweight
    Modesty.metrics.should include :foo/:bar/:creation_page/:lightweight
    Modesty.metrics.should include :baz/:creation_page/:heavyweight
    Modesty.metrics.should include :baz/:creation_page/:middleweight
    Modesty.metrics.should include :baz/:creation_page/:lightweight
  end
end

describe "A/B testing" do
  before :all do
    Modesty.identify :default
    Modesty.set_store :mock
  end

  it "Selects evenly between alternatives" do
    (0..(3*100-1)).each do |i|
      Modesty.identify! i
      [:lightweight, :middleweight, :heavyweight].each do |alt|
        Modesty.ab_test :creation_page/alt do
          Modesty.track! :baz/:creation_page/alt
          Modesty.metrics[:baz/:creation_page/alt].values.should be_close i/3, 2+i/6
        end
      end
      Modesty.metrics[:baz].values.should == 1+i
    end
  end

  it "tracks the number of users in each experimental group" do
    e = Modesty.experiments[:creation_page]
    e.users.should == 3*100
    [:lightweight, :middleweight, :heavyweight].each do |alt|
      e.users(alt).should be_close 3*100/4, 2 + 3*100/6
    end
  end

  it "uses cached values" do
    class Modesty::Experiment
      alias old_generate generate_alternative
      def generate_alternative
        raise RuntimeError
      end
    end
    # should ask Redis for the correct alternative
    # instead of running generate_alternative
    lambda do
      (0..(3*100-1)).each do |i|
        Modesty.identify! i
        Modesty.experiments[:creation_page].ab_test
      end
    end.should_not raise_error
    class Modesty::Experiment
      alias generate_alternative old_generate
    end
  end

  it "allows for manually setting your experiment group" do
    Modesty.identify! 50
    e = Modesty.experiments[:creation_page]
    3.times do
      e.alternatives.each do |alt|
        e.chooses alt
        e.ab_test.should == alt
      end
    end
  end
end