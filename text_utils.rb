def match_square_brackets(str)
  r_i = depth = 0
  found_open = false
  start = str.index('[')  # Note - we assume that the regex had a match on an opening/close [] so we skip a second check here
  for i in start...str.length
    case str[i]
    when '['
      depth += 1
      found_open = true
    when ']'
      depth -= 1
    end
    if found_open and depth == 0
      r_i = i
      found_open = false
      break
    end
  end
  return str[0..r_i]
end
