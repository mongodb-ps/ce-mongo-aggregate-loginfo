#require 'spec_helper'

require_relative '../agg_redact_utils'

RSpec.describe RedactHelpers do
  it 'will redact this string' do
    expect(RedactHelpers.redact_string('blahblah')).to eq('<:>')
    expect(RedactHelpers.redact_string('$myField')).to eq('$myField')
    expect(RedactHelpers.redact_string('$$myVariable')).to eq('$$myVariable')
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
    expect(RedactHelpers.redact_innermost_parameters({ 'from' => "warehouses", 'let' => { 'order_item' => "$item", 'order_qty' => "$ordered" }, 'pipeline' => [ { '$match' => { '$expr' => { '$and' => [ { '$eq' => [ "$stock_item",  "$$order_item" ] }, { '$gte' => [ "$instock", "$$order_qty" ] } ] } } }, { '$project' => { 'stock_item' => 0, '_id' => 0 } } ], 'as' => "stockdata" })).to eq({ 'from' => "warehouses", 'let' => { 'order_item' => "$item", 'order_qty' => "$ordered" }, 'pipeline' => [ { '$match' => { '$expr' => { '$and' => [ { '$eq' => [ "$stock_item",  "$$order_item" ] }, { '$gte' => [ "$instock", "$$order_qty" ] } ] } } }, { '$project' => { 'stock_item' => 0, '_id' => 0 } } ], 'as' => "stockdata" })
  end
  
  it 'will redact $graphLookup' do
  end
end
