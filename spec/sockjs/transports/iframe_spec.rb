# encoding: utf-8
require "spec_helper"
require "sockjs"
require "sockjs/transports/iframe"

describe SockJS::Transports::IFrame, :type => :transport do
  describe "#handle(request)" do
    let(:transport) do
      described_class.new(connection, sockjs_url: "http://sock.js/sock.js")
    end

    let(:response) do
      transport.handle(request)
    end

    context "If-None-Match header matches ETag of current body" do
      let(:request) do
        @request ||= FakeRequest.new.tap do |request|
          etag = '"af0ca7deb5298aeb946c4f7b96d1501b"'
          request.if_none_match = etag
          request.path_info = "/iframe.html"
        end
      end

      it "should respond with HTTP 304" do
        expect(response.status).to eql(304)
      end
    end

    context "If-None-Match header doesn't match ETag of current body" do
      let(:request) do
        @request ||= FakeRequest.new.tap do |request|
          request.path_info = "/iframe.html"
        end
      end

      it "should respond with HTTP 200" do
        expect(response.status).to eql(200)
      end

      it "should respond with HTML MIME type" do
        expect(response.headers["Content-Type"]).to match("text/html")
      end

      it "should set ETag header"

      it "should set cache control to be valid for the next year" do
        time = Time.now + 31536000

        expect(response.headers["Cache-Control"]).to eql("public, max-age=31536000")
        expect(response.headers["Expires"]).to eql(time.gmtime.to_s)
        expect(response.headers["Access-Control-Max-Age"]).to eql("1000001")
      end

      it "should return HTML wrapper in the body" do
        response # Run the handler.
        expect(response.chunks.last).to match(/document.domain = document.domain/)
      end

      it "should set sockjs_url" do
        response # Run the handler.
        expect(response.chunks.last).to match(transport.options[:sockjs_url])
      end
    end
  end
end
