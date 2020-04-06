require 'json'

#
class Stats
  def initialize(num, max, tot, output)
    @num = num
    @max = max
    @output = output
    @total = tot
  end
  attr_reader :num, :max, :output, :total
end

def match_square_brackets(str)
  r_i = 0
  depth = 0
  found_first = false
  for i in 0...str.length
    case str[i]
    when '['
      depth += 1
      found_first = true
    when ']'
      depth -= 1
    end
    if found_first and depth == 0
      r_i = i
      found_first = false
    end
  end
  return str[0..r_i]
end

def remove_in_clauses(str)
  return str.gsub(/\$in:\s+\[[^\[\]]*\]/,'$in: [ <removed> ]')
end

def format_stats(pipeline, exec_times)
  exec_times.sort!
  min = exec_times[0]
  max = exec_times[exec_times.size - 1]
  tot = exec_times.inject(0.0) { | sum, val | sum + val }
  avg = tot / exec_times.size

  output_line = sprintf("%s\t\t\t\t%d\t%d\t%d\t%.2f\t%d", pipeline, exec_times.size, min, max, avg, tot)
  return exec_times.size, max, tot, output_line
end

def quote_object_types(str)
  return str.gsub(/(ObjectId\('[a-f0-9]+'\))/, '"\1"')
end

def quote_json_keys(str)
  quoted_object_types = quote_object_types(str)
  return quoted_object_types.gsub(/([a-zA-Z0-9_$\.]+):/, '"\1":')
end

def redact_innermost_parameters(pipeline)
  retval = {}
  if not pipeline.is_a?(Hash)
    return pipeline
  end
  
  pipeline.each do |k,v|
    puts v
    puts v.class
    puts v.is_a?(Hash)
    case v
    when String
      retval[k] = "redacted"

    when Float
      retval[k] = -0.0
      
    when Numeric
      retval[k] = 0
      
    when Array
      retarr = []
      v.each { |v| retarr.push(redact_innermost_parameters(v)) }
      retval[k] = retarr
      
    when Hash
      retval[k] = redact_innermost_parameters(v)

    else
      retval[k] = "redacted parameters"
    end
  end
  return retval
end

pipelines = {}

ARGF.each do |line|
  matches = line.match(/(.+command\s+(\S+)\s+command:\s+aggregate\s+(\{\s+aggregate:\s+\"(.+)\",\s+(pipeline:\s+\[.*)protocol:op_.+ (\d+))ms$)/)
  unless matches.nil?
    if matches.length > 0
      all, namespace, aggregate, collection, pl, exec_time = matches.captures
      #pipeline = namespace + "\t\t" + remove_in_clauses(match_square_brackets(pl))
      pipeline = collection + "\t\t" + match_square_brackets(pl)
      puts pipeline
      json_conv = '{ ' + quote_json_keys(match_square_brackets(pl)) + ' }'
      puts(json_conv)
      pl_hash = JSON.parse(json_conv)
      puts pl_hash
      puts redact_innermost_parameters(pl_hash)

      if not pipelines.key?(pipeline)
        pipelines[pipeline] = Array(exec_time.to_f)
      else
        pipelines[pipeline].push(exec_time.to_f)
      end
    end
  end
end

sorted_output = []
pipelines.each do |pipeline, stats|
  num_exec, max, tot, output = format_stats(pipeline, stats)
  sorted_output.push(Stats.new(num_exec, max, tot, output))
end

sorted = sorted_output.sort_by { | element | element.num }.reverse!
puts "Namespace\t\tpipeline\t\t\t\tcount\tmin\tmax\taverage\ttotal"
sorted.each { | element | printf("%s\n",  element.output) }
