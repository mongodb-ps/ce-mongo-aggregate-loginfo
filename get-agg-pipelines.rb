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

pipelines = {}

ARGF.each do |line|
  matches = line.match(/(\{\s+aggregate:\s+\"(.+)\",\s+(pipeline:\s+\[.*)protocol:op_msg (\d+)ms$)/)
  unless matches.nil?
    #puts match
    if matches.length > 0
      all, collection, pl, exec_time = matches.captures
      pipeline = collection + "\t\t" + remove_in_clauses(match_square_brackets(pl))

      if not pipelines.key?(pipeline)
        pipelines[pipeline] = Array(exec_time)
      else
        pipelines[pipeline].push(exec_time)
      end
    end
  end
end

pipelines.each do |p|
  puts p
end
