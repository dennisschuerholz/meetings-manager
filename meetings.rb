#!/bin/env ruby

require 'csv'

### CONFIG START ###
debug = false
timediff = 30
filename = "~/.config/meetings/meetings.csv"
# Der erste Key in av_modes ist der Standardmodus, dies möchte man ggf. auch noch anpassen
### CONFIG END ###

puts "debug mode on" if debug

av_modes = {
  "all" => "Zeigt alle Meetings an",
  "now" => "Zeigt aktuell laufende (+/- #{timediff} Minuten) Meetings an",
  "today" => "Zeigt alle am aktuellen Tag stattfindene Meetings an",
  "day <Wochentag|Datum>" => "Zeigt alle am angebenen Datum oder Wochentag stattfindenden Meetings an",
  "help" => "Zeigt diese Hilfe an",
}
# TODO: implement cron mode (GUI Window to accect/select or decline joining the next meeting)
clean_keys = av_modes.keys.map {|s| s.split[0]}
wdays = %w(Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag)


mode = ARGV[0] unless ARGV.empty?
mode = clean_keys.first unless clean_keys.include? mode
puts "mode: #{mode}" if debug
if mode == "day"
  day = ARGV[1] || Date.today
end
if mode == "help"
  puts "Meeting Manager by Dennis Schürholz, https://dennisschuerholz.de"
  puts "Verwendung: #{File.basename($0, File.extname($0))} [#{av_modes.keys.sort.join '|'}]"
  av_modes.keys.sort.each do |key|
    puts "  #{key}#{(av_modes.keys.first == key)?" (Standard)":""}:\n    #{av_modes[key]}"
  end
  exit
end

day = Date.today unless day
if day.is_a? String
  weekday = day
else
  weekday = wdays[day.wday]
end
puts "day: #{day}, weekday: #{weekday}" if debug
puts "current time: #{Time.now.strftime("%H:%M")}" if debug

table = CSV.parse(File.read(File.expand_path(filename)), headers: true)
table.map {|mtg| (mtg['wday'] = wdays[Date.parse(mtg[0]).wday]) rescue mtg['wday'] =  mtg[0] }
table.map {|mtg| if mtg[7] == "Zoom" && mtg[6] == "" then mtg[6] = "zoommtg://zoom.us/join?confno=#{mtg[8]}" end }
unless mode == "all"
  puts "filtering" if debug
  if debug
    table.each do |mtg| puts "mtg[0]: #{mtg[0]}, mtg['wday']: #{mtg['wday']}, mtg[1]: #{mtg[1]}, mtg[2]: #{mtg[2]}" end
  end
  table.delete_if {|mtg| mtg['wday'] != weekday }
  # TODO implement filtering irregular events based on date
  if mode == 'now'
    table.delete_if {|mtg| mtg[1] > (Time.now + timediff*60).strftime("%H:%M") || mtg[2] < (Time.now - timediff*60).strftime("%H:%M") }
  end
end
len = "#{table.length+1}".length
table.each_with_index do |mtg, id|
  puts "[%#{len}d] #{mtg[0]}, #{mtg[1]}-#{mtg[2]}: #{mtg[4]} (#{mtg[10]}) via #{mtg[7]}" % (id+1)
  puts "#{" "*(len+2)} #{mtg[3]} (#{mtg[5]||'N.N.'})"
  puts "#{" "*(len+2)} *optional*" if mtg[11] == "ja"
  puts "#{" "*(len+2)} Kommentar: #{mtg[12]}" if mtg[12]
end
sel = STDIN.gets.chomp.to_i-1  || exit
exit if sel < 0 || sel >= table.length
url = table[sel][6]
if table[sel][7] == "Zoom"
  url.sub! '?', '&'
  url.sub! /https:\/\/(.*)\.zoom\.us\/j\//, 'zoommtg://\1.zoom.us/join?confno='
end
puts "opening #{url}" if debug
puts "Falls notwendig lautet das Passwort: #{table[sel][9]}" if table[sel][9]
system "gnome-open \"#{url}\""
