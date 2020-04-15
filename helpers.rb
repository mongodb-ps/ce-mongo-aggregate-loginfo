#
# Accumulated statistics helper class
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
# Aggregation pipelines are uniquely identified by a combination of
# collection name and (redacted) pipeline
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
