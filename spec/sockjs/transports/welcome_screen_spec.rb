#!/usr/bin/env bundle exec rspec
# encoding: utf-8

require "spec_helper"

require "sockjs"
require "sockjs/transports/welcome_screen"

describe SockJS::Transports::WelcomeScreen do
  describe "#handle(request)" do
    let(:transport) do
      described_class.new(Object.new, Hash.new)
    end

    let(:request) do
      @request ||= FakeRequest.new
    end

    let(:response) do
      transport.handle(request)
    end

    it "should respond with HTTP 200" do
      expect(response.status).to eql(200)
    end

    it "should respond with plain text MIME type" do
      expect(response.headers["Content-Type"]).to match("text/plain")
    end

    it "should return greeting in the body" do
      response # Run the handler.
      expect(response.chunks.last).to eql("Welcome to SockJS!\n")
    end
  end
end
