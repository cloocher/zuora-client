#!/usr/bin/env ruby
#
# Copyright 2010 Ning
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'savon'

class ZuoraClient
  PROD_URL = 'https://www.zuora.com/apps/services/a/21.0'
  SANDBOX_URL = 'https://apisandbox.zuora.com/apps/services/a/23.0'

  def initialize(username, password, url=PROD_URL, verbose=false)
    @username = username
    @password = password

    Savon::Request.log = verbose
    login_client = Savon::Client.new url
    login_client.request.http.ssl_client_auth :verify_mode => OpenSSL::SSL::VERIFY_NONE

    response = login_client.login! do |soap|
      soap.namespace = 'http://api.zuora.com/'
      soap.body = {
          'wsdl:username' => username,
          'wsdl:password' => password
      }
    end.to_hash

    @session = response[:login_response][:result][:session]
    # apparently, the server url might change from the one called above - need to use the one returned
    @client = Savon::Client.new response[:login_response][:result][:server_url]
    @client.request.http.ssl_client_auth :verify_mode => OpenSSL::SSL::VERIFY_NONE
  end

  def query(query_string)
    begin
      response = @client.query! do |soap|
        soap.namespace = 'http://api.zuora.com/'
        soap.header['wsdl:SessionHeader'] = {'wsdl:session' => @session}
        soap.body = {'wsdl:queryString' => query_string}
      end.to_hash
    rescue Savon::SOAPFault => e
      puts e.message
      exit 1
    end

    result = []
    records = response[:query_response][:result][:records]
    if records
      ignore_fields = [:type, :ns2, :xsi]
      records = [records] unless records.is_a?(Array)
      records.each do |record|
        result << record.reject { |k, v| ignore_fields.include?(k) }
      end
    end
    result
  end
end