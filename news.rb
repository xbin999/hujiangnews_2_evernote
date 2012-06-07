#!/usr/bin/ruby -w
# encoding: utf-8

require "net/http"
require "uri"

uri = URI.parse("http://bulo.hujiang.com/menu/news/")
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Get.new(uri.request_uri)
response = http.request(request)

if response.code == "200"
	user_regexp = %r{
		(?<article_id> [0-9]+ ){0}
		(?<article_date> [0-9]+ ){0}
		(?<article_title> [\u0000-\uffff]+? ){0}
		(?<article_url> [^\s]*? ){0}
		【新闻天天译\g<article_id>】\g<article_date>[ ]*[（|(]\g<article_title>[）|)][\u0000-\uffff]*?href=\"\g<article_url>\"
	}x
	r = user_regexp.match(response.body.force_encoding('utf-8'))
	if r
		puts "The newst article is: #{r[:article_id]}, #{r[:article_date]}, #{r[:article_title]}, #{r[:article_url]}"

		if not FileTest::exist?("/tmp/articles/#{r[:article_date]}.txt")
			request2 = Net::HTTP::Get.new(r[:article_url] + "/")
			response2 = http.request(request2)
		
			user_regexp2 = %r{
				(?<article_body> [\u0000-\uffff]+?){0}
				翻译内容：\g<article_body>原文链接
			}x
			r2 = user_regexp2.match(response2.body.force_encoding('utf-8'))
			article = r2[:article_body].gsub(/[[:cntrl:]]/,"").gsub(/\'javascript:[\u0000-\uffff]+\'/,"\'").gsub(/\<br\>/,"\n").gsub(/\<[\u0000-\uffff]*?\>/,"")
			
			o_file = File.open("/tmp/articles/#{r[:article_date]}.txt", "w")
			o_file.puts article
			o_file.close
		end
	end 
end
