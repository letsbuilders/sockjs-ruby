#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/xhr"

describe "XHR", :type => :transport, :em => true do
  describe SockJS::Transports::XHRPost do
    transport_handler_eql "/xhr", "POST"

    describe "#handle(request)" do
      let(:request) do
        FakeRequest.new.tap do |request|
          request.session_key = Array.new(7) { rand(256) }.pack("C*").unpack("H*").first
          request.path_info = "/xhr"
        end
      end

      context "with a session" do
        before :each do
          session
        end

        let(:request) do
          FakeRequest.new.tap do |request|
            request.path_info = "/xhr"
            request.session_key = "b"
          end
        end

        it "should respond with HTTP 200" do
          expect(response.status).to eql(200)
        end

        it "should respond with javascript MIME type" do
          expect(response.headers["Content-Type"]).to match("application/javascript")
        end

        it "should run user code"
      end

      context "without a session" do
        let :session do
        end

        it "should create one and send an opening frame" do
          expect(response.chunks.last).to eql("o\n")
        end

        it "should respond with HTTP 200" do
          expect(response.status).to eql(200)
        end

        it "should respond with javascript MIME type" do
          expect(response.headers["Content-Type"]).to match("application/javascript")
        end

        it "should set access control" do
          expect(response.headers["Access-Control-Allow-Origin"]).to eql(request.origin)
          expect(response.headers["Access-Control-Allow-Credentials"]).to eql("true")
        end

        it "should set session ID" do
          cookie = response.headers["Set-Cookie"]
          expect(cookie).to match("JSESSIONID=#{request.session_id}; path=/")
        end
      end
    end
  end

  describe SockJS::Transports::XHROptions do
    transport_handler_eql "/xhr", "OPTIONS"

    describe "#handle(request)" do
      let(:request) do
        FakeRequest.new
      end

      it "should respond with HTTP 204" do
        expect(response.status).to eql(204)
      end

      it "should set access control" do
        expect(response.headers["Access-Control-Allow-Origin"]).to eql(request.origin)
        expect(response.headers["Access-Control-Allow-Credentials"]).to eql("true")
      end

      it "should set cache control to be valid for the next year" do
        time = Time.now + 31536000

        expect(response.headers["Cache-Control"]).to eql("public, max-age=31536000")
        expect(response.headers["Expires"]).to eql(time.gmtime.to_s)
        expect(response.headers["Access-Control-Max-Age"]).to eql("1000001")
      end

      it "should set Allow header to OPTIONS, POST" do
        expect(response.headers["Allow"]).to eql("OPTIONS, POST")
      end
    end
  end

  describe SockJS::Transports::XHRSendPost do
    transport_handler_eql "/xhr_send", "POST"

    describe "#handle(request)" do
      let(:request) do
        FakeRequest.new.tap do |request|
          request.session_key = rand(1 << 32).to_s
          request.path_info = "/xhr_send"
        end
      end

      context "with a session" do
        before :each do
          session
        end

        context "well formed request" do

          let(:request) do
            FakeRequest.new.tap do |request|
              request.path_info = "/xhr_send"
              request.session_key = 'b'
              request.data = '["message"]'
            end
          end

          it "should respond with HTTP 204" do
            expect(response.status).to eql(204)
          end

          it "should respond with plain text MIME type" do
            expect(response.headers["Content-Type"]).to match("text/plain")
          end

          it "should set session ID" do
            cookie = response.headers["Set-Cookie"]
            expect(cookie).to match("JSESSIONID=#{request.session_id}; path=/")
          end

          it "should set access control" do
            expect(response.headers["Access-Control-Allow-Origin"]).to eql(request.origin)
            expect(response.headers["Access-Control-Allow-Credentials"]).to eql("true")
          end
        end

        context "badly formed JSON" do
          let(:request) do
            FakeRequest.new.tap do |request|
              request.path_info = "/xhr_send"
              request.session_key = 'b'
              request.data = '["message"'
            end
          end

          it "should respond with HTTP 500" do
            expect(response.status).to eql(500)
          end

          it "should report JSON error" do
            response
            request.chunks.join("").should =~ /Broken JSON encoding/
          end
        end

        context "empty body" do
          let(:request) do
            FakeRequest.new.tap do |request|
              request.path_info = "/xhr_send"
              request.session_key = 'b'
              request.data = ''
            end
          end

          it "should respond with HTTP 500" do
            expect(response.status).to eql(500)
          end

          it "should report JSON error" do
            response
            request.chunks.join("").should =~ /Payload expected\./
          end
        end
      end

      context "without a session" do
        it "should respond with HTTP 404" do
          expect(response.status).to eql(404)
        end

        it "should respond with plain text MIME type" do
          expect(response.headers["Content-Type"]).to match("text/plain")
        end

        it "should return error message in the body" do
          response # Run the handler.
          expect(request.chunks.last).to match(/Session is not open\!/)
        end
      end
    end
  end

  describe SockJS::Transports::XHRSendOptions do
    transport_handler_eql "/xhr_send", "OPTIONS"

    describe "#handle(request)" do
      let(:request) do
        FakeRequest.new
      end

      it "should respond with HTTP 204" do
        expect(response.status).to eql(204)
      end

      it "should set access control" do
        expect(response.headers["Access-Control-Allow-Origin"]).to eql(request.origin)
        expect(response.headers["Access-Control-Allow-Credentials"]).to eql("true")
      end

      it "should set cache control to be valid for the next year" do
        time = Time.now + 31536000

        expect(response.headers["Cache-Control"]).to eql("public, max-age=31536000")
        expect(response.headers["Expires"]).to eql(time.gmtime.to_s)
        expect(response.headers["Access-Control-Max-Age"]).to eql("1000001")
      end

      it "should set Allow header to OPTIONS, POST" do
        expect(response.headers["Allow"]).to eql("OPTIONS, POST")
      end
    end
  end

  describe SockJS::Transports::XHRStreamingPost do
    transport_handler_eql "/xhr_streaming", "POST"

    describe "#handle(request)" do
      let :session do
      end

      let(:transport) do
        transport  = described_class.new(connection, Hash.new)

        def transport.try_timer_if_valid(*)
        end

        transport
      end

      let(:request) do
        FakeRequest.new.tap do |request|
          request.path_info = "/a/b/xhr_streaming"
          request.session_key = "b"
        end
      end

      it "should respond with HTTP 200" do
        expect(response.status).to eql(200)
      end

      it "should respond with prelude + open frame" do
        response
        request.chunks.join("").should =~ /hhhhhhhhh\no/
      end

      it "should respond with javascript MIME type" do
        expect(response.headers["Content-Type"]).to match("application/javascript")
      end

      it "should set access control" do
        expect(response.headers["Access-Control-Allow-Origin"]).to eql(request.origin)
        expect(response.headers["Access-Control-Allow-Credentials"]).to eql("true")
      end

      it "should set session ID" do
        cookie = response.headers["Set-Cookie"]
        expect(cookie).to match("JSESSIONID=#{request.session_id}; path=/")
      end
    end
  end

  describe SockJS::Transports::XHRStreamingOptions do
    transport_handler_eql "/xhr_streaming", "OPTIONS"

    describe "#handle(request)" do
      let(:request) do
        FakeRequest.new
      end

      it "should respond with HTTP 204" do
        expect(response.status).to eql(204)
      end

      it "should set access control" do
        expect(response.headers["Access-Control-Allow-Origin"]).to eql(request.origin)
        expect(response.headers["Access-Control-Allow-Credentials"]).to eql("true")
      end

      it "should set cache control to be valid for the next year" do
        time = Time.now + 31536000

        expect(response.headers["Cache-Control"]).to eql("public, max-age=31536000")
        expect(response.headers["Expires"]).to eql(time.gmtime.to_s)
        expect(response.headers["Access-Control-Max-Age"]).to eql("1000001")
      end

      it "should set Allow header to OPTIONS, POST" do
        expect(response.headers["Allow"]).to eql("OPTIONS, POST")
      end
    end
  end
end
