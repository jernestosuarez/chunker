require 'pp'
require 'json'
require 'ruby-progressbar'
require 'slop'
require 'terminal-table'
require 'fileutils'
require 'time'


def execute(command,ask=false)
    if ask
        puts "Execute: #{command}"
        puts "Sure to execute?(s/N)"
        pepe = gets
    else
        pepe = "s"
    end
    if pepe.match(/[sS]/)
        #puts "Executing"
        result=`#{command}`
        #Smooth exit when the command is not success
        return nil unless $?.exitstatus == 0
        return result
    else
        puts "Avoiding"
    end
end

def parse(cadena)
    begin
     JSON.parse(cadena, symbolize_names: true)
    rescue Exception => e
        puts "Error! #{e.message}"
        return Hash.new
    end
end

def check_dependencies
    ret=execute("ffmpeg -L")
    return false if ret.empty?
    ret=execute("ffprobe -L")
    return false if ret.empty?
    return true
end

def parse_times(timefile)
    result = []
    times = timefile.split("\n")
    times.each do |t|
        time= Time.parse(t)
        from = time - 5
        from = from.hour * 3600 + from.min * 60 + from.sec
        to = time + 5
        to = to.hour * 3600 + to.min * 60 + to.sec
        result << [from.to_f, to.to_f]
    end
    return result
end

opts = Slop.parse do |o|
    o.on '-h', '--help', 'Displays this help' do
        puts %x[cat README.md]
        exit
    end
    o.string '-i', '--input', 'Input file'
    o.string '-t', '--times', 'File with the times'
    o.bool '-v', '--verbose', 'enable verbose mode'
    o.on '--version', 'Print the version' do
      puts "v0.1b"
      exit
    end
  end

[73, 32, 99, 97, 110, 39, 116, 32, 98, 101, 32, 109, 111, 114, 101, 32, 118, 101, 114, 98, 111, 115, 101, 32, 116, 104, 97, 110, 32, 116, 104, 105, 115, 46, 46, 46, 32, 83, 111, 114, 114, 121].map{|m| m.chr}.join("") if opts.verbose?
raise "I need an input file!" unless opts.input?
raise "I need a times file!" unless opts.times?

raise "Unable to read the input file" unless File.exists?opts[:input]
raise "Unable to read the times file" unless File.exists?opts[:times]

raise "This script depends on ffmpeg and ffprobe, please install it" unless check_dependencies
#We are storing here each of the fragments in groups of 2

timesfile=File.read(opts[:times])
@times =parse_times(timesfile)
inputfile = opts[:input]
output=inputfile.split(".")
extension=output.pop
output_prefix=output.join(".")


puts "Cutting the video in some chunks..."
progressbar = ProgressBar.create(:title => "Chunking",
                                :total => @times.size,
                                :length => 100,
                                :format         => "%t (%a) %b\u{15E7}%i %p%% ",
                                :progress_mark  => ' ',
                                :remainder_mark => "\u{FF65}",
                                :starting_at    => 0)
           
# Working with results
@times.each_with_index do |time,index|
    from = time[0]
    to = time[1]
    #puts "Chunking from second #{from} to second #{to}"
    raise "Error executing this shit!" unless execute("ffmpeg -i #{inputfile} -ss #{from} -t #{to} -c copy #{output_prefix}_part#{index}.#{extension}")
    progressbar.increment
end

@header = ["from","to"]
@rows = @times

puts Terminal::Table.new :headings => @header, :rows => @rows
puts "\u{1F37A} Done! (you owe me \u{1F37A}\u{1F37A} ;)"