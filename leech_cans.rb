#!/usr/bin/env ruby

require 'base64'
require 'nokogiri'
require 'optparse'
require 'typhoeus'
require 'yaml'

o = {}
responses = {}
routes = {
  add: '/search/search_zusatz.php',
  hnr: '/search/search_hnr.php',
  streets: '/search/search_strassen.php'
}
y = {}

OptionParser.new do |opts|
  opts.banner = "Usage: leech_cans.rb [o]"

  opts.on('-h', '--host HOST', 'Host of informations') { |v| o[:host] = v }
end.parse!

abort('Do not forget to tell the host via -h arg') unless o[:host]

responses[:streets] = Typhoeus::Request.new(
  o[:host] + routes[:streets],
  method: :post,
  body: {
    hidden_kalenderart: 'privat',
    input_hnr: "Hausnummer",
    input_str: "",
    str_id: ""
  },
)

responses[:streets].on_body do |chnk|
  dom = Nokogiri::HTML(chnk)
  dom.css('li').each_with_index do |li, indx|
    if !li.blank? and indx < 1
      node_id = li.attribute('id').content
      str_id = node_id[4..-1] if node_id
      if li.last_element_child and str_id
        y[str_id] = {
          name: li.last_element_child.content,
          nrs: []
        }

        req = Typhoeus::Request.new(
          o[:host] + routes[:hnr],
          method: :post,
          body: {
            hidden_kalenderart: 'privat',
            str_id: str_id
          },
        )

        req.on_body do |i_chnk|
          lis = Nokogiri::HTML(i_chnk)
          lis.css('li').each_with_index do |i_li, i_indx|
            if !i_li.blank? and i_indx
              hnr_id = i_li.attribute('id').content[4..-1]
              if i_li.last_element_child and hnr_id
                y[str_id][:nrs] << {
                  id: hnr_id,
                  nr: i_li.last_element_child.content,
                }
              end
            end
          end
        end

        req.run
      end
    else
      #puts "Empty: #{li}"
    end
  end
end

responses[:streets].run

puts YAML.dump(y)
puts "P.S.: Done full queries, but output on streets & house numbers is just sliced, as it would produce too much output on STDOUT. Happy Easter!"

