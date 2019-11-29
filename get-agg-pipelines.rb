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

  output_line = sprintf("%s\t\t\t%d\t%d\t%.2f\t%d", pipeline, min, max, avg, tot)
  return exec_times.size, max, tot, output_line
end

pipelines = {}

ARGF.each do |line|
  matches = line.match(/(.+command\s+(\S+)\s+command:\s+aggregate\s+(\{\s+aggregate:\s+\"(.+)\",\s+(pipeline:\s+\[.*)protocol:op_msg (\d+))ms$)/)
  unless matches.nil?
    if matches.length > 0
      all, namespace, aggregate, collection, pl, exec_time = matches.captures
      pipeline = namespace + "\t\t" + remove_in_clauses(match_square_brackets(pl))

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

sorted = sorted_output.sort_by { | element | element.total }.reverse!
sorted.each { | element | printf("%d\t%s\n", element.num, element.output) }
