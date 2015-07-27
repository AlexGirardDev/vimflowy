require 'coffee-script/register'
TestCase = require '../testcase.coffee'

boldKey = 'meta+b'
italicizeKey = 'meta+i'

# test insert mode
t = new TestCase ['']
t.sendKeys 'i'
t.sendKeys 'normal, '
t.sendKey italicizeKey
t.sendKeys 'italic, '
t.sendKey boldKey
t.sendKeys 'bold italic, '
t.sendKey italicizeKey
t.sendKeys 'bold'
t.expect [
  {
    text:   'normal, italic, bold italic, bold'
    bold:   '                .................'
    italic: '        .....................    '
  }
]
t.sendKey 'esc'
# beginning of line, gets cursor correctly
t.sendKeys '0iab'
t.sendKey 'esc'
t.expect [
  {
    text:   'abnormal, italic, bold italic, bold'
    bold:   '                  .................'
    italic: '          .....................    '
  }
]
t.sendKeys '0cWv'
t.sendKey 'esc'
t.expect [
  {
    text:   'vitalic, bold italic, bold'
    bold:   '         .................'
    italic: '......................    '
  }
]
# uses style left of cursor
t.sendKeys 'Wia'
t.sendKey 'right'
t.sendKeys 'r'
t.sendKey 'esc'
t.expect [
  {
    text:   'vitalic, abrold italic, bold'
    bold:   '          ..................'
    italic: '........................    '
  }
]

t.sendKeys 'yy'
# replace preserves style
t.sendKeys 'flrafora'
t.sendKey 'esc'
t.expect [
  {
    text:   'vitalic, abroad italic, bald'
    bold:   '          ..................'
    italic: '........................    '
  }
]

# pastes properly
t.sendKeys 'p'
t.expect [
  {
    text:   'vitalic, abroad italic, bald'
    bold:   '          ..................'
    italic: '........................    '
  }
  {
    text:   'vitalic, abrold italic, bold'
    bold:   '          ..................'
    italic: '........................    '
  }
]

# test going onto next line 'enter' in insert mode
t = new TestCase ['']
t.sendKeys 'i'
t.sendKey boldKey
t.sendKeys 'this'
t.sendKey 'enter'
t.sendKeys 'is'
t.sendKey 'enter'
t.sendKey italicizeKey
t.sendKeys 'bold'
t.expect [
  {
    text:   'this'
    bold:   '....'
  }
  {
    text:   'is'
    bold:   '..'
  }
  {
    text:   'bold'
    bold:   '....'
    italic: '....'
  }
]
t.sendKey 'esc'
t.sendKeys 'onormal'
t.expect [
  {
    text:   'this'
    bold:   '....'
  }
  {
    text:   'is'
    bold:   '..'
  }
  {
    text:   'bold'
    bold:   '....'
    italic: '....'
  }
  'normal'
]
t.sendKey 'esc'

# test xp
t = new TestCase [
  {
    text:   'bim'
    bold:   '. .'
    italic: ' ..'
  }
]
t.sendKeys 'xp'
t.expect [
  {
    text:   'ibm'
    bold:   ' ..'
    italic: '. .'
  }
]
