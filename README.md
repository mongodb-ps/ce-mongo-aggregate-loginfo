# What does this script do?

It attempts to parse out aggregation pipeline information from the mongod.log files and aggregate the information in a way similar to mloginfo --queries. The purpose is to accumulate information about longer-running aggregation pipeline shapes, determine how often they were executed during the timeframe covered by the log file(s) and produce a summary showing the aggegation pipeline shape, how often it was executed, plus their minimum/maximum/average and total execution times.

The tool accepts a list of MongoDB log files on the command line. It will process all of the file in sequence and print out the accumulated data across all files.

# How do I run it?

First, you need to have ruby installed. I originally tested it with Ruby 2.3, but expect 2.3 and newer to work with the script.

You can pipe the a log file into the script via stdin:

`cat mongo.log | ruby mdb-agg-info.rb`

Alternatively, you can point it at a log file:

`ruby mdb-agg-info.rb mongod.log`

# Command line parameters

Other than the list of files, the tool takes the following parameters:

Parameter | What it does
----------|--------------
--help | displays a brief usage messages
--exact-duplicates | Don't redact the aggregation pipeline parameters, accumulate the data on the aggregation pipelines with all parameters intact. Useful for finding exact duplicate aggregation pipelines instead of pipelines that have the same shape.

# Environment considerations

The script has tested with MongoDB 3.6 and 4.0 so far.
