require 'test_helper'
require 'rackstash'

describe Rackstash do
  let(:log_output){ StringIO.new }
  let(:base_logger){ Logger.new(log_output) }
  def json
    JSON.parse(log_output.string.lines.to_a.last)
  end

  subject do
    Rackstash::BufferedLogger.new(base_logger)
  end

  describe "fields" do
    after do
      Rackstash.fields = HashWithIndifferentAccess.new
    end

    it "can be defined as a Hash" do
      Rackstash.fields = {:foo => :bar}
      Rackstash.fields.must_be_instance_of HashWithIndifferentAccess

      subject.info("foo")
      json["@fields"]["foo"].must_equal "bar"
    end

    it "can be defined as a proc" do
      Rackstash.fields = proc do
        {:foo => :baz}
      end

      subject.info("foo")
      json["@fields"]["foo"].must_equal "baz"
    end

    it "can be defined as a lambda" do
      Rackstash.fields = lambda do
        {:foo => :baz}
      end

      subject.info("foo")
      json["@fields"]["foo"].must_equal "baz"
    end
  end

  describe "request_fields" do
    after do
      Rackstash.request_fields = HashWithIndifferentAccess.new
    end

    let(:controller) do
      Struct.new(:request).new(Struct.new(:status).new(200))
    end

    it "won't be included in unbuffered mode" do
      Rackstash.request_fields = {:foo => :bar}

      subject.info("foo")
      json["@fields"].keys.wont_include "foo"
    end

    it "can be defined as a hash" do
      Rackstash.request_fields = {:foo => :bar}

      Rackstash.request_fields(controller).must_be_instance_of HashWithIndifferentAccess
      Rackstash.request_fields(controller).must_equal({"foo" => :bar})

      # TODO: fake a real request and ensure that the field gets set in the log output
    end

    it "can be defined as a proc" do
      Rackstash.request_fields = proc do |request|
        {
          :foo => :bar,
          :status => request.status
        }
      end

      Rackstash.request_fields(controller).must_be_instance_of HashWithIndifferentAccess
      Rackstash.request_fields(controller).must_equal({"foo" => :bar, "status" => 200})

      # TODO: fake a real request and ensure that the field gets set in the log output
    end

    it "can be defined as a lambda" do
      Rackstash.request_fields = lambda do |request|
        {
          :foo => :bar,
          :status => request.status
        }
      end

      Rackstash.request_fields(controller).must_be_instance_of HashWithIndifferentAccess
      Rackstash.request_fields(controller).must_equal({"foo" => :bar, "status" => 200})

      # TODO: fake a real request and ensure that the field gets set in the log output
    end
  end

  describe "tagged" do
    def log_lines
      log_output.string.lines.map { |line| JSON.parse(line) }
    end

    before do
      @original_logger = Rackstash.logger
      Rackstash.logger = subject
    end

    after do
      Rackstash.logger = @original_logger
    end

    it "opens a buffer when none is open" do
      Rackstash.tagged("foo") { subject.info("Hello") }

      log_lines.size.must_equal 1
      json["@tags"].must_equal ["foo"]
      json["@message"].must_equal "   [INFO] Hello"
    end

    it "writes into the open buffer instead of a nested buffer" do
      subject.with_buffer do
        subject.fields[:status] = 200
        subject.info("Started")
        Rackstash.tagged("foo") do
          subject.fields[:controller] = "documents"
          subject.info("Completed")
        end
      end

      log_lines.size.must_equal 1
      json["@tags"].must_equal ["foo"]
      json["@message"].must_equal "   [INFO] Started\n   [INFO] Completed"
      json["@fields"]["status"].must_equal 200
      json["@fields"]["controller"].must_equal "documents"
      json["@fields"].keys.wont_include "child_log_ids"
      json["@fields"].keys.wont_include "parent_log_id"
    end

    it "adds no tag for the empty array from Rails::Rack::Logger" do
      subject.with_buffer do
        subject.tagged([]) { subject.info("Hello") }
      end

      log_lines.size.must_equal 1
      json["@tags"].must_equal []
    end
  end
end
