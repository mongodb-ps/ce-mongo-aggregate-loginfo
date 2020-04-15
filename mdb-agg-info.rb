#!/usr/bin/env ruby

require 'json'
require_relative 'helpers.rb'
require_relative 'text_utils.rb'
require_relative 'agg_redact_utils.rb'

STATS_FORMAT = "\t%10d\t%10d\t%10d\t%10.2f\t%10d"

def format_stats(pipeline, exec_times, max_coll_name_len, max_pl_len)
  exec_times.sort!
  min = exec_times[0]
  max = exec_times[exec_times.size - 1]
  tot = exec_times.inject(0.0) { | sum, val | sum + val }
  avg = tot / exec_times.size

  output_line = pipeline.collection + (' ' * (max_coll_name_len - pipeline.collection.length + 1)) +
                "\t" + pipeline.pipeline + (' ' * (max_pl_len - pipeline.pipeline.length + 1)) +
                sprintf(STATS_FORMAT, exec_times.size, min, max, avg, tot)
  return exec_times.size, max, tot, output_line
end


def usage()
  puts "Usage: mdb-agg-info [--help] [--exact-duplicates] <files>"
  exit(1)
end

def process_argv()
  redact = true
  if ARGV.length > 0
    ARGV.each do |arg|
      case arg
      when '--help'
        usage()
      when '--exact-duplicates'
        redact = false
        ARGV.delete('--exact-duplicates')
      end
    end
  else
    usage()
  end
  return redact
end

pipelines = {}

oversize_match = Regexp.new('warning: log line attempted \(\d+kB\) over max size \(10kB\), printing beginning and end').freeze
oversize_count = 0

pipeline_match = Regexp.new('(.+command\s+(\S+)\s+command:\s+aggregate\s+(\{\s+aggregate:\s+\"(.+)\",\s+(pipeline:\s+\[.*)protocol:op_.+ (\d+))ms$)').freeze

max_coll_len = max_pl_len = 0

redact_parameters = process_argv()
unless redact_parameters
  puts 'Running in exact duplicates mode'
end

ARGF.each do |line|
  matches = pipeline_match.match(line)
  unless matches.nil? or matches.length == 0
    if oversize_match.match?(line)
      oversize_count += 1
    else
      all, namespace, aggregate, collection, pl, exec_time = matches.captures

      pl_hash = JSON.parse('{ ' + RedactHelpers.quote_json_keys(match_square_brackets(pl)) + ' }')

      json_output = redact_parameters ? RedactHelpers.redact_innermost_parameters(pl_hash).to_json : pl_hash.to_json

      max_coll_len = [ collection.length, max_coll_len ].max
      max_pl_len = [ json_output.length, max_pl_len].max

      pl_key = PipelineInfo.new(collection, json_output)
      
      if pipelines.key?(pl_key)
        pipelines[pl_key].push(exec_time.to_f)
      else
        pipelines[pl_key] = Array(exec_time.to_f)
      end
    end
  end
end

unless oversize_count == 0
  printf "%d overlength lines detected and skipped\n\n", oversize_count
end

sorted_output = []
pipelines.each do |pipeline, stats|
  num_exec, max, tot, output = format_stats(pipeline, stats, max_coll_len, max_pl_len)
  sorted_output.push(Stats.new(num_exec, max, tot, output))
end

sorted = sorted_output.sort_by { | element | [ element.num, element.total ] }.reverse!
puts 'Collection' + (' ' * [max_coll_len - 9, 1].max) + "\tPipeline" + (' ' * [max_pl_len - 7, 1].max) + "\t  count   \t  min (ms)\t  max (ms)\t average  \t total"
sorted.each { | element | printf("%s\n",  element.output) }
