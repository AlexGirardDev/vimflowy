require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test search
t = new TestCase [
  'blah',
  'searchblah',
  'blahsearchblah',
  'search',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    'search',
  ] }
]
t.sendKeys '/search'
t.sendKey 'enter'
t.sendKeys 'dd'
t.expect [
  'blah',
  'blahsearchblah',
  'search',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    'search',
  ] }
]

# test search
t = new TestCase [
  'blah',
  'searchblah',
  'blahsearchblah',
  'search',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    'search',
  ] }
]
t.sendKeys '/search'
t.sendKey 'ctrl+j'
t.sendKey 'enter'
t.sendKeys 'dd'
t.expect [
  'blah',
  'searchblah',
  'search',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    'search',
  ] }
]

t = new TestCase [
  'blah',
  'searchblah',
  'blahsearchblah',
  'search',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    'search',
  ] }
]
t.sendKeys '/search'
t.sendKey 'ctrl+j'
t.sendKey 'ctrl+j'
t.sendKey 'enter'
t.sendKeys 'dd'
t.expect [
  'blah',
  'searchblah',
  'blahsearchblah',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    'search',
  ] }
]

# test search canceling
t = new TestCase [
  'blah',
  'searchblah',
  'blahsearchblah',
  'search',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    'search',
  ] }
]
t.sendKeys '/search'
t.sendKey 'esc'
t.sendKeys 'dd'
t.expect [
  'searchblah',
  'blahsearchblah',
  'search',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    'search',
  ] }
]

t = new TestCase [
  'blah',
  'searchblah',
  'blahsearchblah',
  'search',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    'search',
  ] }
]
t.sendKeys '/search'
t.sendKey 'ctrl+k'
t.sendKey 'enter'
t.sendKeys 'dd'
t.expect [
  'blah',
  'searchblah',
  'blahsearchblah',
  'search',
  'surch',
  { line: 'blahsearch', children: [
    'blah',
  ] }
  { line: 'blah', children: [
    # NOTE: a new line is created since it got changed to be the view root
    '',
  ] }
]

