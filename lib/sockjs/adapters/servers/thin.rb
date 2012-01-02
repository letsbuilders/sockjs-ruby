# encoding: utf-8

require "forwardable"

require_relative "./rack"

module SockJS
  module Thin
    class Request < Rack::Request
      # We need to access the async.callback.
      attr_reader :env
    end


    # This is just to make Rack happy.
    # For explanation how does it work check
    # http://macournoyer.com/blog/2009/06/04/pusher-and-async-with-thin
    DUMMY_RESPONSE ||= [-1, Hash.new, Array.new]


    class Response < Response
      extend Forwardable

      attr_reader :body
      def initialize(request, status = nil, headers = Hash.new, &block)
        @request, @body   = request, DelayedResponseBody.new
        @status, @headers = status, headers

        block.call(self) if block
      end

      def async?
        true
      end

      def write_head(status = nil, headers = nil)
        super(status, headers) do
          if @headers["Content-Length"]
            raise "WTF, Content-Length with chunking? Get real mate!"
          end

          unless @status == 204
            @headers["Transfer-Encoding"] = "chunked"
          end

          callback = @request.env["async.callback"]

          puts "~ Headers: #{@headers.inspect}"

          callback.call([@status, @headers, @body])
        end
      end

      def_delegator :body, :write
      def_delegator :body, :finish
    end


    class DelayedResponseBody
      include EventMachine::Deferrable

      TERM ||= "\r\n"
      TAIL ||= "0#{TERM}#{TERM}"

      def initialize
        @status = :created
        super # TODO: Is this necessary?
      end

      def call(body)
        body.each do |chunk|
          self.write(chunk)
        end
      end

      def write(chunk)
        unless @status == :opened
          raise "Body isn't open (status: #{@status})"
        end

        unless chunk.respond_to?(:bytesize)
          raise "Chunk is supposed to respond to #bytesize, but it doesn't.\nChunk: #{chunk.inspect} (#{chunk.class})"
        end

        STDERR.puts("~ body#write #{chunk.inspect}")
        data = [chunk.bytesize.to_s(16), TERM, chunk, TERM].join
        self.__write__(data)
      end

      def each(&block)
        @status = :opened
        @body_callback = block
      end

      def succeed
        self.__write__(TAIL)
        @status = :closed
        super
      end

      alias_method :finish, :succeed

      protected
      def __write__(data)
        @body_callback.call(data)
      end
    end
  end
end
