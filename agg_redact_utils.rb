require 'json'


module RedactHelpers
  def self.quote_object_types(str)
    if str =~ /(ObjectId\(["'][a-f0-9]+['"]\))/
      str = str.gsub(/ObjectId\(['"]([a-f0-9]+)['"]\)/, '"ObjectId(\'\1\')"')
    end
    if str =~ /(BinData\(\d+,\s*[a-zA-Z0-9=\+\/]+\))/
      str = str.gsub(/(BinData\(\d+,\s*[a-zA-Z0-9=\+\/]+\))/, '"\1"')
    end
    if str =~/new Date\(.+\)/
      str = str.gsub(/(new Date\(['"]*([\d\-\.:TZ]+)['"]*\))/, '"new Date(\2)"')
    end
    return str
  end

  def self.quote_json_keys(str)
    quoted_object_types = quote_object_types(str)
    return quoted_object_types.gsub(/([{,]\s*)([$\. \(\)\w-]+?)\s?(:\s*)/, '\1"\2"\3')
  end

  def self.quote_regex(str)
    return str.gsub(/\"\$regex\":\s+(\/.*\/)/, '"$regex": "\1"')
  end

  
  # Expressions that should only be partially redacted, ie
  # redact the value but not the field the operation works on
  PART_REDACT = [ '$eq', '$ne', '$gte', '$gt', '$lte', '$lt' ]

  def self.partial_redaction_only?(key)
    return PART_REDACT.include?(key)
  end

  # Check if we're in an in clause
  def self.in_clause?(key)
    return key == "$in"
  end

  # Usually these functions have fields as operands/values or the values are
  # significant (in the case of $exists) so don't redact them
  VAL_OK = [ '$max', '$min', '$sum', '$avg', '$exists' ]

  def self.dont_redact_val?(key)
    return VAL_OK.include?(key)
  end

  # Don't redact the subdocuments for these operations
  SUBDOC_OK = [ '$sort', '$project', '$group' ]

  def self.dont_redact_subdoc?(key)
    return SUBDOC_OK.include?(key)
  end

  # Check if the operation contains an object type
  # TODO - Add support for more datatypes like BinData and TimeStamp
  def self.contains_object_or_variable?(s)
    return s =~ /(ObjectId\(.+\)|new Date\(.+\)|new NumberDecimal\(.+\)|BinData\(.+\)|^\$+\w+)/
  end

  # If the string matches an object type, try to
  # redact the contents instead of the whole value
  def self.redact_object_or_variable(s)
    if s =~ /new\s+Date\(["'\d\:\.TZ-]+\)/
      "new Date()"
    elsif s =~ /ObjectId\(.+\)/
      'ObjectId()'
    elsif s =~ /^\$+\w+/
      s
    elsif s =~ /BinData\(.+\)/
      s.gsub(/BinData\((\d+),\s*[a-zA-Z0-9=\+\/]+\)/, 'BinData(\1, <:>)')
    else
      '<:>'
    end
  end

  def self.redact_string(s)
    return contains_object_or_variable?(s) ? redact_object_or_variable(s) : "<:>"
  end

  # Check if the key for the subdocument implies that the subdocument
  # needs special treatment for redaction.
  def self.special_subdoc_redact?(k)
    return [ '$lookup', '$graphLookup' ].include?(k)
  end


  def self.redact_special_functions(k, v)
    case k
    when '$lookup'
      tmp_subdoc = {}
      v.each do | k, v |
        case k
        when 'from'
          tmp_subdoc['from'] = v
        when 'let'
          tmp_subdoc['let'] = redact_innermost_parameters(v)
        when 'pipeline'
          redacted = []
          v.each do |entry|
            redacted.push(redact_innermost_parameters(entry))
          end
          tmp_subdoc['pipeline'] = redacted
        else
          tmp_subdoc[k] = v
        end
      end
      return tmp_subdoc
    when '$graphLookup'
      return v
    end
  end

  def self.redact_innermost_parameters(pipeline)
    retval = {}
    if not pipeline.is_a?(Hash)
      # puts "Pipeline is " + pipeline.to_s + " and is of type " + pipeline.class.to_s
      case pipeline
      when Array
        retval = Array.new()
        pipeline.each { |element|
          retval.push(redact_innermost_parameters(element))
        }
        return retval
        
      when String
        return redact_string(pipeline)

      when Float
        return -0.0

      when Integer
        return -0

      when true, false
        #puts "bool value triggered"
        return "bool"
      end
    else
      pipeline.each do |k,v|
        case v
        when true, false
          retval[k] = dont_redact_val?(k) ? v : "bool"
          
        when String
          retval[k] = dont_redact_val?(k) ? v : redact_string(v)

        when Float
          retval[k] = -0.0
          
        when Integer
          retval[k] = dont_redact_val?(k) ? v : -0

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
          if dont_redact_subdoc?(k)
            retval[k] = v
          elsif special_subdoc_redact?(k)
            retval[k] = redact_special_functions(k, v)
          else
            retval[k] = redact_innermost_parameters(v)
          end
        else
          if v.nil?
            #puts "Warning - nil value for key " + k
            retval[k] = "null"
          else
            puts "Error - shouldn't have made it here with value " + v.to_s
          end
          retval[k] = [true, false].include?(v) ? 'bool' : '<:!:>'
        end
      end
    end
    return retval
  end
end
