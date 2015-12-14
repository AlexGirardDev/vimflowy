TestCase = require '../testcase.coffee'

swapDownKey = 'ctrl+j'
swapUpKey = 'ctrl+k'

describe "cloning", () ->
  it "works in basic case", () ->
    t = new TestCase [
      { text: 'one', children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
      ] }
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]
    t.sendKeys 'yc'
    t.sendKeys 'jjj'
    t.sendKeys 'p'
    t.expect [
      { text: 'one', id: 1, children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
        { clone: 1 }
      ] }
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]

  it "works editing both clone and original; works with basic movement", () ->
    t = new TestCase [
      { text: 'one', children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
      ] }
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]
    t.sendKeys 'yc'
    t.sendKeys 'jjj'
    t.sendKeys 'p'
    t.sendKeys 'gg'
    t.sendKeys 'x'
    t.sendKeys 'jjjj'
    t.sendKeys 'x'
    t.expect [
      { text: 'e', id: 1, children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
        { clone: 1 }
      ] }
      { text: 'tacos', children: [
        'tacos',
      ] }
    ]

    # test movement from the clone
    t.sendKeys 'jj'
    t.sendKeys 'x'
    t.expect [
      { text: 'e', id: 1, children: [
        'uno',
      ] }
      { text: 'two', children: [
        'dos',
        { clone: 1 }
      ] }
      { text: 'acos', children: [
        'tacos',
      ] }
    ]

  it "works with movement in complex case", () ->
    t = new TestCase [
      { text: 'Clone', children: [
          'Clone child'
      ] }
      { text: 'Not a clone', children: [
        'Also not a clone and going to be deleted'
      ] }
    ]
    t.sendKeys 'yc'
    t.sendKeys 'jjjj'
    t.sendKeys 'p'
    t.expect [
      { text: 'Clone', id: 1, children: [
        'Clone child',
      ] }
      { text: 'Not a clone', children: [
        'Also not a clone and going to be deleted'
        { clone: 1 }
      ] }
    ]
    t.sendKeys 'kddk'
    t.expect [
      { text: 'Clone', id: 1, children: [
        'Clone child',
      ] }
      { text: 'Not a clone', children: [
        { clone: 1 }
      ] }
    ]
    t.expectCursor 3, 0
    # test movement
    t.sendKeys 'k'
    t.expectCursor 2, 0
    t.sendKeys 'k'
    t.expectCursor 1, 0
    t.sendKeys 'k'
    t.expectCursor 1, 0

  it "prevents cloning to a sibling", () ->
    t = new TestCase [
      'one',
      'two',
      'three'
    ]
    t.sendKeys 'yc'
    t.sendKeys 'j'
    t.sendKeys 'p'
    t.expect [
      'one',
      'two',
      'three'
    ]

  it "prevents cycles", () ->
    t = new TestCase [
      { text: 'one', children: [
        'uno',
      ] }
    ]
    t.sendKeys 'yc'
    t.sendKeys 'j'
    t.sendKeys 'p'
    t.expect [
      { text: 'one', children: [
        'uno',
      ] }
    ]

  it "prevents cycles part 2", () ->
    t = new TestCase [
      { text: 'blah', children: [
        'blah'
      ] }
      { text: 'eventually cloned', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'jdd'
    t.expect [
      'blah'
      { text: 'eventually cloned', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'jjyckP'
    t.expect [
      'blah'
      { text: 'Will be cloned', id: 4, children: [
        'Will be cloned'
      ] }
      { text: 'eventually cloned', children: [
        { clone: 4 }
      ] }
    ]
    t.sendKeys 'jjyckp'
    t.expect [
      'blah'
      { text: 'Will be cloned', id: 4, children: [
        'Will be cloned'
      ] }
      { text: 'eventually cloned', children: [
        { clone: 4 }
      ] }
    ]
    t.sendKeys 'kp'
    t.expect [
      'blah'
      { text: 'Will be cloned', id: 4, children: [
        'Will be cloned'
      ] }
      { text: 'eventually cloned', children: [
        { clone: 4 }
      ] }
    ]
    t.sendKeys 'u'
    t.expect [
      'blah'
      { text: 'eventually cloned', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'u'
    t.expect [
      { text: 'blah', children: [
        'blah'
      ] }
      { text: 'eventually cloned', children: [
        { text: 'Will be cloned', children: [
          'Will be cloned'
        ] }
      ] }
    ]
    t.sendKeys 'p'
    t.expect [
      { text: 'blah', children: [
        'blah'
        { text: 'eventually cloned', id: 3, children: [
          { text: 'Will be cloned', children: [
            'Will be cloned'
          ] }
        ] }
      ] }
      { clone: 3 }
    ]


  it "works with repeat", () ->
    t = new TestCase [
      'one'
      'two'
      { text: 'three', children: [
        'child',
      ] }
    ]
    t.sendKeys '2yc'
    t.sendKeys 'p'
    t.expect [
      'one'
      'two'
      { text: 'three', children: [
        'child',
      ] }
    ]
    t.sendKeys 'jjp'
    t.expect [
      { text: 'one', id: 1 }
      { text: 'two', id: 2 }
      { text: 'three', children: [
        { clone: 1 }
        { clone: 2 }
        'child',
      ] }
    ]

  it "does not add to history when constraints are violated", () ->
     t = new TestCase [
       'blah'
       { text: 'Will be cloned', children: [
         'not a clone'
       ] }
     ]
     t.sendKeys 'x'
     t.expect [
       'lah'
       { text: 'Will be cloned', children: [
         'not a clone'
       ] }
     ]
     t.sendKeys 'jycp'
     t.expect [
       'lah'
       { text: 'Will be cloned', children: [
         'not a clone'
       ] }
     ]
     t.sendKeys 'u'
     t.expect [
       'blah'
       { text: 'Will be cloned', children: [
         'not a clone'
       ] }
     ]

  it "enforces constraints upon movement", () ->
    t = new TestCase [
      { text: 'Clone', children: [
        'Clone child'
      ] }
      { text: 'Not a clone', children: [
        'Not a clone'
      ] }
    ]

    t.sendKeys 'ycjjp'
    t.expect [
      { text: 'Clone', id: 1, children: [
        'Clone child'
      ] }
      { text: 'Not a clone', children: [
        { clone: 1 }
        'Not a clone'
      ] }
    ]

    t.sendKeys 'gg'
    t.sendKey swapDownKey
    t.expect [
      { text: 'Clone', id: 1, children: [
        'Clone child'
      ] }
      { text: 'Not a clone', children: [
        { clone: 1 }
        'Not a clone'
      ] }
    ]

    t.sendKeys 'u'
    t.expect [
      { text: 'Clone', children: [
        'Clone child'
      ] }
      { text: 'Not a clone', children: [
        'Not a clone'
      ] }
    ]

    t.sendKeys 'gg'
    t.sendKey swapDownKey
    t.expect [
      { text: 'Not a clone', children: [
        { text: 'Clone', children: [
          'Clone child'
        ] }
        'Not a clone'
      ] }
    ]


  it "creates clone on regular paste", () ->
    t = new TestCase [
      'Will be cloned via delete',
      { text: 'parent', children: [
        'hm...'
      ] }
    ]
    t.sendKeys 'x'
    t.expect [
      'ill be cloned via delete',
      { text: 'parent', children: [
        'hm...'
      ] }
    ]
    t.sendKeys 'dd'
    t.expect [
      { text: 'parent', children: [
        'hm...'
      ] }
    ]
    t.sendKeys 'uu'
    t.expect [
      'Will be cloned via delete',
      { text: 'parent', children: [
        'hm...'
      ] }
    ]
    t.sendKeys 'jp'
    # pastes with the W even though it was deleted while cloned
    t.expect [
      { text: 'Will be cloned via delete', id: 1 }
      { text: 'parent', children: [
        { clone: 1 }
        'hm...'
      ] }
    ]

  it "prevents constraint violation on regular paste", () ->
    t = new TestCase [
      'Will be deleted',
      'hm...'
    ]
    t.sendKeys 'dd'
    t.sendKeys 'u'
    t.expect [
      'Will be deleted',
      'hm...'
    ]
    t.sendKeys 'p'
    t.expect [
      'Will be deleted',
      'hm...'
    ]

  it "prevents constraint violation on paste", () ->
    t = new TestCase [
      'Will be cloned',
      { text: 'parent', children: [
        { text: 'blah', children: [
          'blah'
        ] }
      ] }
    ]
    t.sendKeys 'ycjp'

    t.expect [
      { text: 'Will be cloned', id: 1 },
      { text: 'parent', children: [
        { clone: 1 }
        { text: 'blah', children: [
          'blah'
        ] }
      ] }
    ]

    t.sendKeys 'ddkkp'
    t.expect [
      'Will be cloned',
      { text: 'parent', children: [
        { text: 'blah', children: [
          'blah'
        ] }
      ] }
    ]

  it "prevents constraint violation on indent", () ->
    t = new TestCase [
      { text: 'parent', children: [
        'blah'
      ] }
      'Will be cloned',
    ]
    t.sendKeys 'Gyckp'

    t.expect [
      { text: 'parent', children: [
        'blah'
        { text: 'Will be cloned', id: 3 }
      ] }
      { clone: 3 }
    ]

    t.sendKeys 'G'
    t.sendKeys '>'
    t.expect [
      { text: 'parent', children: [
        'blah'
        { text: 'Will be cloned', id: 3 }
      ] }
      { clone: 3 }
    ]

  it "can paste clones of removed items", () ->
    t = new TestCase [
      'test',
      'hi',
    ]
    t.sendKeys 'jddu'
    t.sendKeys 'yc'
    t.sendKey 'ctrl+r'

    t.expect [
      'test'
    ]

    t.sendKeys 'p'
    t.expect [
      'test'
      'hi'
    ]

  it "can paste clones of removed items, part 2", () ->
    t = new TestCase [
      'test',
    ]
    t.sendKeys 'ohi'
    t.sendKey 'esc'

    t.expect [
      'test'
      'hi'
    ]

    t.sendKeys 'ycu'
    t.expect [
      'test'
    ]

    t.sendKeys 'p'
    # the pasted row is empty, since the typing got undone!
    t.expect [
      'test'
      ''
    ]
