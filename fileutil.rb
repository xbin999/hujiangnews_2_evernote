# encoding: utf-8

def savefile( filename, text)
	o_file = File.open(filename, "w")
	o_file.puts text
	o_file.close
end

def loadfile( filename)
	return File.read(filename)
end
