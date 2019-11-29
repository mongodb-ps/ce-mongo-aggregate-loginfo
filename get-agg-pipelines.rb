#
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

def print_stats(pipeline, exec_times)
  exec_times.sort!
  min = exec_times[0]
  max = exec_times[exec_times.size - 1]
  avg = exec_times.inject(0.0) { | sum, val | sum + val } / exec_times.size

  printf("%s\t\t\t%d\t%d\t%.2f\n", pipeline, min, max, avg)
end

pipelines = {}

ARGF.each do |line|
  matches = line.match(/(\{\s+aggregate:\s+\"(.+)\",\s+(pipeline:\s+\[.*)protocol:op_msg (\d+)ms$)/)
  unless matches.nil?
    if matches.length > 0
      all, collection, pl, exec_time = matches.captures
      pipeline = collection + "\t\t" + remove_in_clauses(match_square_brackets(pl))

      if not pipelines.key?(pipeline)
        pipelines[pipeline] = Array(exec_time.to_f)
      else
        pipelines[pipeline].push(exec_time.to_f)
      end
    end
  end
end

pipelines.each do |key, value|
  print_stats(key, value)
end
