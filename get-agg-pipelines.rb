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
    #puts i
  end
  return str[0..r_i]
end

pipelines = {}

ARGF.each do |line|
  #match_group = line.scan(/(\{ aggregate: \"(.+)\", (pipeline: \[.+\]) \})/)
  #matches = line.match(/(\{ aggregate: \"(.+)\",\s+(pipeline:\s+\[.+\])\s*\})/)
  #matches = line.match(/(\{ aggregate: \"(.+)\",\s+pipeline:\s+(?<pipeline>\[[^\[\]]*\g<pipeline>*\])\s*\})/)
  #matches = line.match(/(pipeline:\s+(?<pipeline>\[[^\[\]]*\g<pipeline>*\]))/)
  matches = line.match(/(\{\s+aggregate:\s+\"(.+)\",\s+(pipeline:\s+\[.*)protocol:op_msg (\d+)ms$)/)
  unless matches.nil?
    #puts match
    if matches.length > 0
      all, collection, pl, exec_time = matches.captures
      #all, collection, pipeline = matches.captures
      #puts collection
      pipeline = match_square_brackets(pl)
      #puts exec_time

      if not pipelines.key?(pipeline)
        pipelines[pipeline] = Array(exec_time)
      else
        exec_times = pipelines[pipeline]
        exec_times.push(exec_time)
        pipelines[pipeline] = exec_times
      end
    end
  end
end

pipelines.each do |p|
  puts p
end
