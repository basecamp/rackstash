require 'test_helper'
require 'rackstash'
require 'rack'

require 'stringio'
require 'tmpdir'
require 'fileutils'

describe Rackstash::LogMiddleware do
  let(:log_output){ StringIO.new }
  let(:public_path){ Dir.mktmpdir }
  let(:app){ lambda { |env| [200, {}, ["OK"]] } }

  subject do
    Rackstash::LogMiddleware.new(app)
  end

  before do
    Rackstash.logger = Rackstash::BufferedLogger.new(Logger.new(log_output))
    FileUtils.mkdir_p(File.join(public_path, "stylesheets"))
    File.write(File.join(public_path, "robots.txt"), "")
    File.write(File.join(public_path, "stylesheets", "screen.css"), "")
  end

  after do
    Rackstash.quiet_assets = false
    Rackstash.public_path = nil
    FileUtils.rm_rf(public_path)
  end

  def get(path)
    subject.call(Rack::MockRequest.env_for(path))
  end

  def records
    log_output.string.lines.map { |line| JSON.parse(line) }
  end

  it "writes a record for a file in public_path by default" do
    Rackstash.public_path = public_path
    get "/robots.txt"

    records.size.must_equal 1
    records.first["@fields"]["path"].must_equal "/robots.txt"
  end

  describe "with quiet_assets" do
    before do
      Rackstash.quiet_assets = true
      Rackstash.public_path = public_path
    end

    it "writes no record for a file in public_path" do
      get "/robots.txt"
      get "/stylesheets/screen.css?1234"

      records.must_be_empty
    end

    it "writes a record for a path that is not a file in public_path" do
      get "/stylesheets"
      get "/stylesheets/missing.css"
      get "/projects/1"

      records.map { |record| record["@fields"]["path"] }.must_equal %w[ /stylesheets /stylesheets/missing.css /projects/1 ]
    end

    it "writes a record for a path that leaves public_path" do
      get "/../#{File.basename(public_path)}/robots.txt"

      records.size.must_equal 1
    end

    it "writes a record when public_path is not set" do
      Rackstash.public_path = nil
      get "/robots.txt"

      records.size.must_equal 1
    end
  end
end
