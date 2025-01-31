# Get list of all the tests in format for TODO.todo.
require 'socket'
Bundler.require(:default, :development)

task :unpack_tests do
  version = "0.3.4"

  tests = {}
  File.foreach("protocol/sockjs-protocol-#{version}.py").each_with_object(tests) do |line, buffer|
    if line.match(/class (\w+)\(Test\)/)
      buffer[$1] = Array.new
    elsif line.match(/def (\w+)/)
      if buffer.keys.last
        buffer[buffer.keys.last] << $1
      end
    end
  end

  require "yaml"
  puts tests.to_yaml
end

desc "Run the protocol tests from https://github.com/sockjs/sockjs-protocol"
task :protocol_test, [:port] => 'protocol_test:run'

namespace :protocol_test do
  task :run, [:port] => [:collect_args, :client] do |task, args|
  end

  task :collect_args, [:port] do |task, args|
    $TEST_PORT = (args[:port] || ENV["TEST_PORT"] || 8081)
  end

  task :check_port do
    begin
      test_conn = TCPSocket.new 'localhost', $TEST_PORT
      fail "Something is still running on localhost:#$TEST_PORT"
    rescue Errno::ECONNREFUSED
      #That's what we're hoping for
    ensure
      test_conn.close rescue nil
    end
  end

  task :run_server => :check_port do
    $server_pid = Process::fork do
      Rake::application.invoke_task "protocol_test:server[#$TEST_PORT]"
    end

    %w{EXIT TERM}.each do |signal|
      trap(signal) do
        puts "Killing #$server_pid"
        sh "ps -lwwwf #$server_pid"
        Process::kill('TERM', $server_pid)
        sleep 1
        Process::kill('TERM', $server_pid)
        Process::wait($server_pid)
      end
    end

    begin_time = Time.now
    begin
      test_conn = TCPSocket.new 'localhost', $TEST_PORT
    rescue Errno::ECONNREFUSED
      if Time.now - begin_time > 10
        raise "Couldn't connect to test server in 10 seconds - bailing out"
      else
        retry
      end
    ensure
      test_conn.close rescue nil
    end
  end

  task :client => :run_server do
    proto_version = ENV["PROTO_VERSION"] ||
      begin
        require 'sockjs/version'
        SockJS::PROTOCOL_VERSION_STRING
      end
    sh "protocol/venv/bin/python protocol/sockjs-protocol-#{proto_version}.py #{ENV["FOCUSED_TESTS"]}" do |ok, res|
      if not ok
        puts "Protocol test suite returned failures (#{res})"
      end
    end
  end

  desc "Run the protocol test server"
  task :server, [:port] do |task, args|
    require "thin"
    require 'em/pure_ruby'
    #require "eventmachine"
    require 'sockjs/examples/protocol_conformance_test'

    $DEBUG = true

    PORT = Integer(args[:port] || 8081)

    ::Thin::Connection.class_eval do
      def handle_error(error = $!)
        log "[#{error.class}] #{error.message}\n  - "
        log error.backtrace.join("\n  - ")
        close_connection rescue nil
      end
    end

    SockJS.debug!
    SockJS.debug "Available handlers: #{::SockJS::Endpoint.endpoints.inspect}"

    protocol_version = args[:version] || SockJS::PROTOCOL_VERSION_STRING
    options = {sockjs_url: "http://cdn.sockjs.org/sockjs-#{protocol_version}.min.js"}
    puts "\n#{__FILE__}:#{__LINE__} => #{options.inspect}"

    app = SockJS::Examples::ProtocolConformanceTest.build_app(options)

    begin
      Thin::Server.start(app, PORT)
    rescue => ex
      p ex.message
    end
  end
end
