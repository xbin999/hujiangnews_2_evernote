# encoding: utf-8
dir2 = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.push("#{dir2}")

require "net/http"
require "uri"
require "yaml"
require "fileutil.rb"

def crawler( http, request_uri, user_regexp)
	request = Net::HTTP::Get.new(request_uri)
	response = http.request(request)
	r = user_regexp.match(response.body.force_encoding('utf-8'))
	return r
end

uri = URI.parse("http://bulo.hujiang.com/menu/news/")
http = Net::HTTP.new(uri.host, uri.port)

user_regexp = %r{
	(?<article_id> [0-9]+ ){0}
	(?<article_date> [0-9]+ ){0}
	(?<article_title> [\u0000-\uffff]+? ){0}
	(?<article_url> [^\s]*? ){0}
	【新闻天天译\g<article_id>】\g<article_date>[（|(| ]\g<article_title>[）|)|<][\u0000-\uffff]*?href=\"\g<article_url>\"
}x

user_regexp2 = %r{
	(?<article_body> [\u0000-\uffff]+?){0}
	翻译内容：\g<article_body>[{原文链接}|{参考译文}]
}x

config = YAML.load_file("#{dir2}/note.yaml")
filedir = config["config"]["dir"]
	
r = crawler( http, uri.request_uri, user_regexp)
if r
	puts "The newst article is: #{r[:article_id]}, #{r[:article_date]}, #{r[:article_title]}, #{r[:article_url]}"
	filename = "#{filedir}/#{r[:article_id]}_#{r[:article_date]}_#{r[:article_title]}.txt"

	if not FileTest::exist?(filename)
		r2 = crawler( http, r[:article_url] + "/", user_regexp2)
		article = r2[:article_body].gsub(/[[:cntrl:]]/,"").gsub(/\'javascript:[\u0000-\uffff]+?\'/,"\'").gsub(/\<br\>/,"\n").gsub(/\<[\u0000-\uffff]*?\>/,"")
		article = "http://bulo.hujiang.com#{r[:article_url]}\n" + article
		savefile( filename, article)
		savefile( "#{filedir}/.write", "#{r[:article_id]}_#{r[:article_date]}_#{r[:article_title]}.txt")
	end
end 
