require 'coffee-script/register'
TestCase = require '../testcase.coffee'

# test backspace
t = new TestCase ['abc']
t.sendKey 'A'
t.sendKey 'backspace'
t.sendKey 'backspace'
t.expect ['a']

t = new TestCase ['abc', 'def']
t.sendKeys 'jli'
t.sendKey 'backspace'
t.expect ['abc', 'ef']
t.sendKey 'backspace'
t.expect ['abcef']
t.sendKey 'backspace'
t.expect ['abef']
t.sendKey 'backspace'
t.expect ['aef']
t.sendKey 'backspace'
t.expect ['ef']
t.sendKey 'backspace'
t.expect ['ef']
t.sendKey 'esc'
t.sendKey 'u'
t.expect ['abc', 'def']

t = new TestCase ['ab', 'cd']
t.sendKeys 'jA'
t.sendKey 'backspace'
t.sendKey 'backspace'
t.expect ['ab', '']
t.sendKey 'backspace'
t.expect ['ab']
t.sendKey 'backspace'
t.expect ['a']

t = new TestCase [
  { line: 'ab', children: [
    'bc'
  ] },
  { line: 'cd', children: [
    'de'
  ] },
]
t.sendKeys 'jji'
t.sendKey 'backspace'
# cannot backspace when there are children
t.expect [
  { line: 'ab', children: [
    { line: 'bccd', children: [
      'de'
    ] },
  ] },
]
t.sendKey 'backspace'
t.sendKey 'backspace'
t.sendKey 'backspace'
t.expect [
  { line: 'abcd', children: [
    'de'
  ] },
]
t.sendKey 'backspace'
t.sendKey 'backspace'
t.sendKey 'backspace'
t.expect [
  { line: 'cd', children: [
    'de'
  ] },
]

t = new TestCase [
  { line: 'ab', children: [
    'cd'
  ] },
]
t.sendKeys 'ji'
t.sendKey 'backspace'
t.expect [
  'abcd'
]
t.sendKey 'esc'
t.sendKeys 'u'
t.expect [
  { line: 'ab', children: [
    'cd'
  ] }
]
t.sendKey 'ctrl+r'
t.expect [
  'abcd'
]
t.sendKey 'x'
t.expect [
  'acd'
]

# test shift+backspace
t = new TestCase ['ab', 'cd']
t.sendKeys 'i'
t.sendKey 'shift+backspace'
t.expect ['b', 'cd']
t.sendKey 'shift+backspace'
t.expect ['', 'cd']
t.sendKey 'shift+backspace'
t.expect ['', 'cd']

# test J join
t = new TestCase ['ab', 'cd']
t.sendKeys 'J'
t.expect ['ab cd']
t.sendKeys 'x'
t.expect ['abcd']

t = new TestCase ['ab', ' cd']
t.sendKeys 'J'
t.expect ['ab cd']
t.sendKeys 'x'
t.expect ['abcd']

t = new TestCase [
  { line: 'ab', children: [
    'cd'
  ] },
]
t.sendKeys 'J'
t.expect ['ab cd']
t.sendKeys 'x'
t.expect ['abcd']

t = new TestCase [
  'ab'
  { line: 'cd', children: [
    'ef'
    'gh'
  ] },
]
t.sendKeys 'J'
t.expect [
  { line: 'ab cd', children: [
    'ef'
    'gh'
  ] },
]
t.sendKeys 'x'
t.expect [
  { line: 'abcd', children: [
    'ef'
    'gh'
  ] },
]

