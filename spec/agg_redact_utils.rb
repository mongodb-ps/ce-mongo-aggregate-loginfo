require_relative '../agg_redact_utils'
require_relative '../text_utils'

RSpec.describe RedactHelpers do
  it 'will correctly quotes special MongoDB object types' do
    expect(RedactHelpers.quote_object_types('pipeline: [ { $match: { _id : ObjectId(\'5e99b89bb50408cbff36f9f0\') } } ]')).to eq('pipeline: [ { $match: { _id : "ObjectId(\'5e99b89bb50408cbff36f9f0\')" } } ]')    
    expect(RedactHelpers.quote_object_types('pipeline: [ { $match: { _id : ObjectId("5e99b89bb50408cbff36f9f0") } } ]')).to eq('pipeline: [ { $match: { _id : "ObjectId(\'5e99b89bb50408cbff36f9f0\')" } } ]')    
    expect(RedactHelpers.quote_object_types('pipeline: [ { $match: { mongo_rocks: BinData(128, 4D6F6E676F444220526F636B73) } } ]')).to eq('pipeline: [ { $match: { mongo_rocks: "BinData(128, 4D6F6E676F444220526F636B73)" } } ]')
  end
  
  it 'will redact this string' do
    expect(RedactHelpers.redact_string('blahblah')).to eq('<:>')
    expect(RedactHelpers.redact_string('$myField')).to eq('$myField')
    expect(RedactHelpers.redact_string('$$myVariable')).to eq('$$myVariable')
  end

  it 'will correctly redact these object types' do
    expect(RedactHelpers.redact_string('new Date("1066-01-01")')).to eq('new Dbate()')
    expect(RedactHelpers.redact_string('ObjectId(\'5e99b89bb50408cbff36f9f0\')')).to eq('ObjectId()')
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
end

RSpec.describe TextUtils do
  it 'will extract the correct pipeline substring' do
  end
end
