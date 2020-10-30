# coding: utf-8
require_relative '../agg_redact_utils'
require_relative '../text_utils'

RSpec.describe RedactHelpers do
  it 'will correctly quote this pipeline expression' do
    expect(RedactHelpers.quote_json_keys('{ pipeline: [ { $match: { test_array: { $exists: true, $ne: [] } } }, { $group: { "_id": 1, n: { $sum: 1 } } } ] }')).to eq('{ "pipeline": [ { "$match": { "test_array": { "$exists": true, "$ne": [] } } }, { "$group": { "_id": 1, "n": { "$sum": 1 } } } ] }')
    expect(RedactHelpers.quote_json_keys('{ $sort: { subdoc.first_field: -1, subdoc.second_field: -1 } }')).to eq('{ "$sort": { "subdoc.first_field": -1, "subdoc.second_field": -1 } }')
  end
  
  it 'will correctly quotes special MongoDB object types' do
    expect(RedactHelpers.quote_object_types('pipeline: [ { $match: { _id : ObjectId(\'5e99b89bb50408cbff36f9f0\') } } ]')).to eq('pipeline: [ { $match: { _id : "ObjectId(\'5e99b89bb50408cbff36f9f0\')" } } ]')    
    expect(RedactHelpers.quote_object_types('pipeline: [ { $match: { _id : ObjectId("5e99b89bb50408cbff36f9f0") } } ]')).to eq('pipeline: [ { $match: { _id : "ObjectId(\'5e99b89bb50408cbff36f9f0\')" } } ]')    
    expect(RedactHelpers.quote_object_types('pipeline: [ { $match: { mongo_rocks: BinData(128, 4D6F6E676F444220526F636B73) } } ]')).to eq('pipeline: [ { $match: { mongo_rocks: "BinData(128, 4D6F6E676F444220526F636B73)" } } ]')
    expect(RedactHelpers.quote_object_types('created: { $gte: new Date(1578132000000), $lt: new Date(1586070000000) }')).to eq('created: { $gte: "new Date(1578132000000)", $lt: "new Date(1586070000000)" }')
    expect(RedactHelpers.quote_object_types('created: { $gte: new Date("2020-01-03T15:36:00.001Z"), $lt: new Date(1586070000000) }')).to eq('created: { $gte: "new Date(2020-01-03T15:36:00.001Z)", $lt: "new Date(1586070000000)" }')
    expect(RedactHelpers.quote_object_types('$match: { _id : { $in: [ ObjectId("5e99b89bb50408cbff36f9f0") ] }, created: { $gte: new Date(1578132000000) } }')).to eq('$match: { _id : { $in: [ "ObjectId(\'5e99b89bb50408cbff36f9f0\')" ] }, created: { $gte: "new Date(1578132000000)" } }')
  end

  it 'will correctly quote this string that contains a colon' do
    expect(RedactHelpers.quote_json_keys('{ "mongodb-conn": "my-mongo-server:27107" }')).to eq('{ "mongodb-conn": "my-mongo-server:27107" }')
    expect(RedactHelpers.quote_json_keys('{ mongodb-conn: "my-mongo-server:27107" }')).to eq('{ "mongodb-conn": "my-mongo-server:27107" }')
    expect(RedactHelpers.quote_json_keys('{ "my-mongo-server:27107": "analytics" }')).to eq('{ "my-mongo-server:27107": "analytics" }')
    expect(RedactHelpers.quote_json_keys('{ namespace : "just random data", from_host: "my-mongo_server:27108" }')).to eq('{ "namespace" : "just random data", "from_host": "my-mongo_server:27108" }')
    expect(RedactHelpers.quote_json_keys('{ "my-mongo-server:27107": "analytics", mongo-purpose : "analytics" }')).to eq('{ "my-mongo-server:27107": "analytics", "mongo-purpose" : "analytics" }')
    expect(RedactHelpers.quote_json_keys('{ "my-mongo-server:27107": "analytics", mongo-purpose : "analytics", keys: 0 }')).to eq('{ "my-mongo-server:27107": "analytics", "mongo-purpose" : "analytics", "keys": 0 }')
    expect(RedactHelpers.quote_json_keys('{ "my-mongo-server:27107": "analytics", mongo-purpose : "analytics", keys: 0, last_updated: new Date(12435056000) }')).to eq('{ "my-mongo-server:27107": "analytics", "mongo-purpose" : "analytics", "keys": 0, "last_updated": "new Date(12435056000)" }')
    expect(RedactHelpers.quote_json_keys('{ "my-mongo-server:27107": "analytics", mongo-purpose : "analytics", keys: 0, last_updated: new Date("2010-10-10T13:01:01Z") }')).to eq('{ "my-mongo-server:27107": "analytics", "mongo-purpose" : "analytics", "keys": 0, "last_updated": "new Date(2010-10-10T13:01:01Z)" }')
  end
  
  it 'will redact this string' do
    expect(RedactHelpers.redact_string('blahblah')).to eq('<:>')
    expect(RedactHelpers.redact_string('$myField')).to eq('$myField')
    expect(RedactHelpers.redact_string('$$myVariable')).to eq('$$myVariable')
  end

  it 'will correctly redact these object types' do
    expect(RedactHelpers.redact_string('new Date("1066-01-01")')).to eq('new Date()')
    expect(RedactHelpers.redact_string('ObjectId(\'5e99b89bb50408cbff36f9f0\')')).to eq('ObjectId()')
    expect(RedactHelpers.redact_string('BinData(128, 4D6F6E676F444220526F636B73)')).to eq('BinData(128, <:>)')
  end

  it 'will redact these simple hashes' do
    expect(RedactHelpers.redact_innermost_parameters({ 'test' => 'blahblah' })).to eq({ 'test' => '<:>' })
    expect(RedactHelpers.redact_innermost_parameters({ 'test' => 0.0 })).to eq({ 'test' => -0.0 })
    expect(RedactHelpers.redact_innermost_parameters({ 'test' => 15.3 })).to eq({ 'test' => -0.0 })
    expect(RedactHelpers.redact_innermost_parameters({ 'test' => 21 })).to eq({ 'test' => -0 })
    expect(RedactHelpers.redact_innermost_parameters({ 'test' => -10 })).to eq({ 'test' => -0 })
    expect(RedactHelpers.redact_innermost_parameters({ 'test' => true })).to eq({ 'test' => 'bool' })
    expect(RedactHelpers.redact_innermost_parameters({ 'test' => false })).to eq({ 'test' => -'bool' })
  end

  it 'will redact these nested hashes' do
    expect(RedactHelpers.redact_innermost_parameters({ 'test' => { 'a' => 'b' } })).to eq({ 'test' => { 'a' => '<:>' } })
  end

  it 'will leave $project alone' do
    expect(RedactHelpers.redact_innermost_parameters({ '$project' => { '_id' => 0, 'test' => 1 } })).to eq({ '$project' => { '_id' => 0, 'test' => 1 } })
  end

  it 'will leave $sort alone' do
    expect(RedactHelpers.redact_innermost_parameters({ '$sort' => { 'first' => 1, 'second' => -1 } })).to eq({ '$sort' => { 'first' => 1, 'second' => -1 } })
  end

  it 'will redact in clauses' do
    expect(RedactHelpers.redact_innermost_parameters({ '$in' => [ '_id', 'test' ] })).to eq({ '$in' => [ '<:>' ] })
    expect(RedactHelpers.redact_innermost_parameters({ '$in' => [ '_id', 0 ] })).to eq({ '$in' => [ '<:>', -0 ] })
  end

  it 'will redact $lookup' do
    expect(RedactHelpers.redact_innermost_parameters({ '$lookup' => { 'from' => "inventory", 'localField' => "item", 'foreignField' => "sku", 'as' => "inventory_docs" } })).to eq({ '$lookup' => { 'from' => "inventory", 'localField' => "item", 'foreignField' => "sku", 'as' => "inventory_docs" } })
    expect(RedactHelpers.redact_innermost_parameters({ '$lookup' => { 'from' => "warehouses", 'let' => { 'order_item' => "$item", 'order_qty' => "$ordered" }, 'pipeline' => [ { '$match' => { '$expr' => { '$and' => [ { '$eq' => [ "$stock_item",  "$$order_item" ] }, { '$gte' => [ "$instock", "$$order_qty" ] } ] } } }, { '$project' => { 'stock_item' => 0, '_id' => 0 } } ], 'as' => "stockdata" } })).to eq({ '$lookup' => { 'from' => "warehouses", 'let' => { 'order_item' => "$item", 'order_qty' => "$ordered" }, 'pipeline' => [ { '$match' => { '$expr' => { '$and' => [ { '$eq' => [ "$stock_item",  "$$order_item" ] }, { '$gte' => [ "$instock", "$$order_qty" ] } ] } } }, { '$project' => { 'stock_item' => 0, '_id' => 0 } } ], 'as' => "stockdata" } })
    expect(RedactHelpers.redact_innermost_parameters({ '$lookup' => { 'from' => "warehouses", 'let' => { 'order_item' => "$item", 'order_qty' => 10 }, 'pipeline' => [ { '$match' => { '$expr' => { '$and' => [ { '$eq' => [ "$stock_item",  13 ] }, { '$gte' => [ "$instock", 35 ] } ] } } }, { '$project' => { 'stock_item' => 0, '_id' => 0 } } ], 'as' => "stockdata" } })).to eq({ '$lookup' => { 'from' => "warehouses", 'let' => { 'order_item' => "$item", 'order_qty' => -0 }, 'pipeline' => [ { '$match' => { '$expr' => { '$and' => [ { '$eq' => [ "$stock_item",  -0 ] }, { '$gte' => [ "$instock", -0 ] } ] } } }, { '$project' => { 'stock_item' => 0, '_id' => 0 } } ], 'as' => "stockdata" } })
  end
  
  it 'will redact $graphLookup' do
    expect(RedactHelpers.redact_innermost_parameters({ '$graphLookup' => { 'from' => "employees", 'startWith' => "$reportsTo", 'connectFromField' => "reportsTo", 'connectToField' => "name", 'as' => "reportingHierarchy" } })).to eq({ '$graphLookup' => { 'from' => "employees", 'startWith' => "$reportsTo", 'connectFromField' => "reportsTo", 'connectToField' => "name", 'as' => "reportingHierarchy" } })
  end

  it 'will not redact boolean on $exists' do
    expect(RedactHelpers.redact_innermost_parameters({ 'my_huge_array' => { '$exists' => true } })).to eq({ 'my_huge_array' => { '$exists' => true } })
    expect(RedactHelpers.redact_innermost_parameters({ 'my_huge_array' => { '$exists' => false } })).to eq({ 'my_huge_array' => { '$exists' => false } })
  end
end

RSpec.describe TextUtils do
  it 'will extract the correct pipeline substring' do
  end
end
