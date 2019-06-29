#!/usr/bin/env ruby

# -------------------------------------------------------------------------- #
# Copyright 2002-2018, OpenNebula Project, OpenNebula Systems                #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
# -------------------------------------------------------------------------- #

require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'rexml/document'

class OneMarket
    ONE_MARKET_URL = 'http://marketplace.opennebula.systems/'
    AGENT          = 'Market Driver'
    VERSION        = ENV['VERSION']

    def initialize(url, dir)
        @url   = url || ONE_MARKET_URL
        @dir   = dir || 'data/appliances'
        @agent = "OpenNebula #{VERSION} (#{AGENT})"
    end

    def get(path)

        # Get proxy params (needed for ruby 1.9.3)
        http_proxy = ENV['http_proxy'] || ENV['HTTP_PROXY']

        if http_proxy
            p_uri   = URI(http_proxy)
            p_host  = p_uri.host
            p_port  = p_uri.port
        else
            p_host  = nil
            p_port  = nil
        end

        uri = URI(@url + path)
        req = Net::HTTP::Get.new(uri.request_uri)

        req['User-Agent'] = @agent

        response = Net::HTTP.start(uri.hostname, uri.port, p_host, p_port) {|http|
            http.request(req)
        }

        if response.is_a? Net::HTTPSuccess
            return 0, response.body
        else
            return response.code.to_i, response.msg
        end
    end

    def get_appliances()
        rc, body = get('/appliance')

        if rc != 0
            return rc, body
        end

        applist     = JSON.parse(body)
        app_file    = ""

        puts "Processing appliances"
        applist['appliances'].each { |app|
            id     = app["_id"]["$oid"]
            source = app["files"][0]["url"]

            tmpl = ""

            print_yaml_var(tmpl, "name",        app["name"])
            print_yaml_var(tmpl, "logo",        "https://marketplace.opennebula.systems//logos/" + app["logo"])
            print_yaml_var(tmpl, "source",      source)
            print_yaml_var(tmpl, "import_id",   id)
            print_yaml_var(tmpl, "origin_id",   "-1")
            print_yaml_var(tmpl, "type",        "IMAGE")
            print_yaml_var(tmpl, "publisher",   app["publisher"])
            print_yaml_var(tmpl, "format",      app["format"])
            print_yaml_var(tmpl, "description", app["short_description"])
            print_yaml_var(tmpl, "version",     app["version"])
            print_yaml_var(tmpl, "tags",        app["tags"].join(', '))
            print_yaml_var(tmpl, "regtime",     app["creation_time"])

            app_file = "#{@dir}/#{app['name'].gsub(/\s+/, '_')}.yaml"
            puts app_file

            if !app["files"].nil? && !app["files"][0].nil?
                file = app["files"][0]
                size = 0

                if (file["size"].to_i != 0)
                    size = file["size"].to_i / (2**20)
                end

                print_yaml_var(tmpl, "size", size)
                print_yaml_var(tmpl, "md5",  file["md5"])

                tmpl64 = ""
                print_var(tmpl64, "DEV_PREFIX", file["dev_prefix"])
                print_var(tmpl64, "DRIVER",     file["driver"])
                print_var(tmpl64, "TYPE",       file["type"])

                if !tmpl64.empty?
                  print_yaml_heredoc(tmpl, "image_template",     tmpl64)
                end
            end

            begin
            if !app["opennebula_template"].nil?
                vmtmpl64 = template_to_str(JSON.parse(app["opennebula_template"]))
                print_yaml_heredoc(tmpl, "vm_template",     vmtmpl64)
            end
            rescue
            end

            File.open(app_file, 'w') { |file| file.write(tmpl) }

        }
    end

    private

    def print_yaml_var(str, name, val)
        return if val.nil?
        return if val.class == String && val.empty?

        val.gsub!('"','\"') if val.class == String

        str << "#{name}: \"#{val}\"\n"
    end
    def print_yaml_heredoc(str, name, val)
        return if val.nil?
        return if val.class == String && val.empty?

        val.gsub!(/^/, '  ') if val.class == String

        str << "#{name}: |\n"
        str << "#{val}\n"
    end
    def print_var(str, name, val)
        return if val.nil?
        return if val.class == String && val.empty?

        val.gsub!('"','\"') if val.class == String

        str << "#{name}= \"#{val}\"\n"
    end

    def template_to_str(thash)
        thash.collect do |key, value|
            next if value.nil? || value.empty?

            str = case value.class.name
            when "Hash"
                attr = "#{key.to_s.upcase} = [ "

                attr << value.collect do |k, v|
                     next if v.nil? || v.empty?
                     "#{k.to_s.upcase}  =\"#{v.to_s}\""
                end.compact.join(",")

                attr << "]\n"
            when "String"
                "#{key.to_s.upcase} = \"#{value.to_s}\""
            end
        end.compact.join("\n")
    end
end

################################################################################
# Main Program. Outpust the list of marketplace appliances
################################################################################

url = ARGV[0] rescue nil
dir = ARGV[1] rescue nil

one_market = OneMarket.new(url, dir)
one_market.get_appliances
