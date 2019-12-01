# What does this script do?

It attempts to parse out aggregation pipeline information from the mongod.log files and aggregate the information in a way similar to mloginfo --queries.

# How do I run it?

First, you need to have ruby installed. I originally tested it with Ruby 2.3, but expect 2.3 and newer to work with the script.

You can pipe the a log file into the script via stdin:

`cat mongo.log | ruby get-agg-pipelines.rb`

Alternatively, you can point it at a log file:

`ruby get-agg-pipelines.rb mongod.log`

# Environment considerations

The script was only tested against MongoDB 4.0.
