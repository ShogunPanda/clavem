#!/usr/bin/env ruby
# encoding: utf-8
#
# This file is part of the clavem gem. Copyright (C) 2013 and above Shogun <shogun@cowtech.it>.
# Licensed under the MIT license, which can be found at https://choosealicense.com/licenses/mit.
#

require "cgi"
require "eventmachine"
require "evma_httpserver"

class ClavemTestServer < EM::Connection
  include EM::HttpServer

  def process_http_request
    query = CGI::parse(@http_query_string)
    url = query["oauth_callback"].first
    token = (query["token"] || []).first
    wait = (query["wait"].first || 0).to_i

    sleep(wait) if wait > 0

    response = EM::DelegatedHttpResponse.new(self)
    response.send_redirect("%s?%s" % [url, token ? "oauth_token=#{token}" : "failure=FAILURE"])
  end
end

["INT", "TERM", "KILL"].each { |signal|
  trap(signal) { EM.stop }
}

EM.run do
  puts "Listening on 0.0.0.0:7779 - Provide a token for a success, otherwise a failure will be triggered."
  EM.start_server("0.0.0.0", 7779, ClavemTestServer)
end