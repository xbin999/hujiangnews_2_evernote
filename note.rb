# encoding: utf-8
#

require 'net/https'
class Net::HTTP
  alias orig_initialize initialize
  def initialize(*args,&blk)
    orig_initialize(*args,&blk)
    self.ca_path = '/etc/ssl/certs' if File.exists?('/etc/ssl/certs') # Ubuntu
    self.ca_file = '/opt/local/share/curl/curl-ca-bundle.crt' if File.exists?('/opt/local/share/curl/curl-ca-bundle.crt') # Mac OS X
    # Ruby uses SSLv23 by default, but here should be TLSv1 to connect evernote
    self.ssl_version = :TLSv1
  end
end

require "digest/md5"

dir2 = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.push("#{dir2}")
require "fileutil.rb"

# Get configurations from YAML file
require "yaml"
config = YAML.load_file("note.yaml")
libpath = config["config"]["libpath"]
filedir = config["config"]["dir"]
authToken = config["config"]["authToken"]

# Read data if the file is newer.
write_id = loadfile("#{filedir}.write").gsub(/\n/,"")
read_id = loadfile("#{filedir}.read").gsub(/\n/,"")
if write_id <= read_id
  puts "#{write_id} has been uploaded, do nothing."
  exit(0)
end
filename = "#{filedir}#{write_id}"
text = loadfile(filename)

# Add the Thrift & Evernote Ruby libraries to the load path.
dir = File.expand_path("#{libpath}")
$LOAD_PATH.push("#{dir}/../../lib")
$LOAD_PATH.push("#{dir}/../../lib/thrift")
$LOAD_PATH.push("#{dir}/../../lib/Evernote/EDAM")

require "thrift/types"
require "thrift/struct"
require "thrift/protocol/base_protocol"
require "thrift/protocol/binary_protocol"
require "thrift/transport/base_transport"
require "thrift/transport/http_client_transport"
require "Evernote/EDAM/user_store"
require "Evernote/EDAM/user_store_constants.rb"
require "Evernote/EDAM/note_store"
require "Evernote/EDAM/limits_constants.rb"

# To get a developer token, visit https://sandbox.evernote.com/api/DeveloperToken.action
evernoteHost = "www.evernote.com"
userStoreUrl = "https://#{evernoteHost}/edam/user"

userStoreTransport = Thrift::HTTPClientTransport.new(userStoreUrl)
userStoreProtocol = Thrift::BinaryProtocol.new(userStoreTransport)
userStore = Evernote::EDAM::UserStore::UserStore::Client.new(userStoreProtocol)

versionOK = userStore.checkVersion("Evernote EDAMTest (Ruby)",
                                Evernote::EDAM::UserStore::EDAM_VERSION_MAJOR,
                                Evernote::EDAM::UserStore::EDAM_VERSION_MINOR)
puts "Is my Evernote API version up to date?  #{versionOK}"
if (!versionOK)
  exit(1)
end

# Get the URL used to interact with the contents of the user's account
# When your application authenticates using OAuth, the NoteStore URL will
# be returned along with the auth token in the final OAuth request.
# In that case, you don't need to make this call.
noteStoreUrl = userStore.getNoteStoreUrl(authToken)

noteStoreTransport = Thrift::HTTPClientTransport.new(noteStoreUrl)
noteStoreProtocol = Thrift::BinaryProtocol.new(noteStoreTransport)
noteStore = Evernote::EDAM::NoteStore::NoteStore::Client.new(noteStoreProtocol)

note = Evernote::EDAM::Type::Note.new()
note.title = File.basename(write_id,'.txt').split('_')[2].force_encoding('ASCII-8BIT')
note.content = '<?xml version="1.0" encoding="UTF-8"?>' +
  '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">' +
  '<en-note>' + text.gsub(/\n/,'<br/>').force_encoding('ASCII-8BIT') + '<br/>' +
  '</en-note>'
note.tagNames = ["english", "translation", "21days"]

createdNote = noteStore.createNote(authToken, note)

# Write flag file.
savefile( "#{filedir}.read", write_id)
puts "Successfully created a new note with GUID: #{createdNote.guid}"
