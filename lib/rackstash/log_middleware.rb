require 'rackstash'

module Rackstash
  class LogMiddleware

    def initialize(app)
      @app = app
    end

    def call(env)
      Rackstash.with_log_buffer do
        request = Rack::Request.new(env)
        Rackstash.logger.do_not_log! if Rackstash.quiet_assets && asset?(request.path_info)
        fields = {
          :method => request.request_method,
          :scheme => request.scheme,
          :path => (request.fullpath rescue "unknown")
        }
        begin
          status, headers, result = @app.call(env)
        ensure
          fields[:status] = status
          Rackstash.logger.fields.reverse_merge!(fields) if Rackstash.logger.fields
        end
      end
    end

    private
      def asset?(path)
        return false unless Rackstash.public_path

        path = Rack::Utils.unescape(path)
        return false if path.include?("..") || path.include?("\0")

        File.file?(File.join(Rackstash.public_path, path))
      end
  end
end
