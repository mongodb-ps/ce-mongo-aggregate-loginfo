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
#
#
class PipelineInfo
  def initialize(collection, pipeline)
    @collection = collection
    @pipeline   = pipeline
  end
  attr_reader :collection, :pipeline

  def ==(rhs)
    self.class === rhs and
      @collection == rhs.collection and
      @pipeline == rhs.pipeline
  end

  def hash
    (@collection + @pipeline).hash
  end

  alias eql? ==
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

def format_stats(pipeline, exec_times, max_coll_name_len, max_pl_len)
  exec_times.sort!
  min = exec_times[0]
  max = exec_times[exec_times.size - 1]
  tot = exec_times.inject(0.0) { | sum, val | sum + val }
  avg = tot / exec_times.size

  #output_line = sprintf("%s\t\t\t\t%d\t%d\t%d\t%.2f\t%d", pipeline, exec_times.size, min, max, avg, tot)
  output_line = pipeline.collection + (' ' * (max_coll_name_len - pipeline.collection.length + 1)) +
                "\t" + pipeline.pipeline + (' ' * (max_pl_len - pipeline.pipeline.length + 1)) +
                sprintf("\t%10d\t%10d\t%10d\t%10.2f\t%10d", exec_times.size, min, max, avg, tot)
  return exec_times.size, max, tot, output_line
end

def quote_object_types(str)
  return str.gsub(/(ObjectId\('[a-f0-9]+'\))/, '"\1"').gsub(/(new Date\(\d+\))/, '"\1"')
end

def quote_json_keys(str)
  quoted_object_types = quote_object_types(str)
  return quoted_object_types.gsub(/([a-zA-Z0-9_$\.]+):/, '"\1":')
end

def partial_redaction_only?(key)
  return [ '$eq', '$ne', '$gte', '$gt', '$lte', '$lt' ].include?(key)
end
  
def in_clause?(key)
  return key == "$in"
end

def dont_redact_val?(key)
  return [ '$max', '$min', '$sum', '$avg' ].include?(key)
end

def redact_innermost_parameters(pipeline)
  retval = {}
  if not pipeline.is_a?(Hash)
    case pipeline
    when String
      return "<redacted>"

    when Float
      return -0.0

    when Integer
      return -0
    end
  else
    pipeline.each do |k,v|
      case v
      when String
        if dont_redact_val?(k)
          retval[k] = v
        else
          retval[k] = "redacted"
        end

      when Float
        retval[k] = -0.0
      
      when Integer
        retval[k] = 0

      when Numeric
        retval[k] = 0
      
      when Array
        retarr = []
        if partial_redaction_only?(k)
          retarr.push(v[0])
          v.drop(1).each { |val| retarr.push(redact_innermost_parameters(val)) }
        elsif in_clause?(k)
          last_val = redact_innermost_parameters(v[0])
          retarr.push(last_val)
          v.drop(1).each do |val|
            cur_val = redact_innermost_parameters(val)
            if last_val != cur_val
              last_val = cur_val
              retarr.push(cur_val)
            end
          end
        else
          v.each { |val| retarr.push(redact_innermost_parameters(val)) }
        end
        retval[k] = retarr
      
      when Hash
        # TODO: Needs to do partial redaction of $project in case
        # we have subdocuments/subexpressions in it
        if k == "$project"
          retval[k] = v
        else
          retval[k] = redact_innermost_parameters(v)
        end
      else
        retval[k] = "redacted parameters"
      end
    end
  end
  return retval
end

pipelines = {}

oversize_match = Regexp.new('warning: log line attempted \(\d+kB\) over max size \(10kB\), printing beginning and end').freeze
oversize_count = 0

pipeline_match = Regexp.new('(.+command\s+(\S+)\s+command:\s+aggregate\s+(\{\s+aggregate:\s+\"(.+)\",\s+(pipeline:\s+\[.*)protocol:op_.+ (\d+))ms$)').freeze

# TODO - make switchable via command line
redact_parameters = true

max_coll_len = max_pl_len = 0

ARGF.each do |line|
  matches = pipeline_match.match(line)
  unless matches.nil? or matches.length == 0
    #puts line
    if not oversize_match.match?(line)
      all, namespace, aggregate, collection, pl, exec_time = matches.captures
      pipeline = collection + "\t\t" + match_square_brackets(pl)
      #puts pipeline
      json_conv = '{ ' + quote_json_keys(match_square_brackets(pl)) + ' }'
      #puts(json_conv)
      pl_hash = JSON.parse(json_conv)

      json_output = redact_parameters ? redact_innermost_parameters(pl_hash).to_json : pl_hash.to_json

      if max_coll_len < collection.length
        max_coll_len = collection.length
      end

      if max_pl_len < json_output.length
        max_pl_len = json_output.length
      end

      pl_key = PipelineInfo.new(collection, json_output)
      
      if not pipelines.key?(pl_key)
        pipelines[pl_key] = Array(exec_time.to_f)
      else
        pipelines[pl_key].push(exec_time.to_f)
      end
    else
      oversize_count += 1
    end
  end
end

printf "%d overlength lines detected that were skipped\n", oversize_count

sorted_output = []
pipelines.each do |pipeline, stats|
  num_exec, max, tot, output = format_stats(pipeline, stats, max_coll_len, max_pl_len)
  sorted_output.push(Stats.new(num_exec, max, tot, output))
end

sorted = sorted_output.sort_by { | element | [ element.num, element.total ] }.reverse!
puts 'Collection' + (' ' * [max_coll_len - 9, 1].max) + "\tPipeline" + (' ' * [max_pl_len - 7, 1].max) + "\t  count   \t  min     \t  max     \t average  \t total"
sorted.each { | element | printf("%s\n",  element.output) }
