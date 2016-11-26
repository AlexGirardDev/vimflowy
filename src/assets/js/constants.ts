import { SerializedBlock } from './types';

type TextProperty = 'bold' | 'italic' | 'underline' | 'strikethrough';
export const text_properties: Array<TextProperty> = ['bold', 'italic', 'underline', 'strikethrough'];

export const empty_data = [''];
export const default_data: Array<SerializedBlock> = [
  'Welcome to vimflowy!',
  '(I hope you know to use j and k to move up and down!)',
  { text: 'Features', children: [
    { text: 'Workflowy features', children: [
      { text: 'Nested bullets', children: [
        'Bullets with children can be collapsed',
        { text: 'Use enter to zoom into any bullet.  Try on this one!', collapsed: true, children: [
          'And shift+enter to zoom all the way back out',
          'Alternatively, ctrl+o jumps back to your old location',
          'Use ] and [ to zoom in and out just one level',
        ] },
        { text: 'Use z to toggle collapsedness', collapsed: true, children: [
          'You found me! :)',
        ] },
        'Use tab and shift+tab to indent and unindent blocks',
        'Use < and > to indent and unindent just a single line',
      ] },
      { text: 'Text formatting', collapsed: true, children: [
        {
          text:      'Bold (ctrl+shift+b), italicized (ctrl+shift+i), and underlined (ctrl+shift+u) text.  Bold italic underlined!',
          bold:      '....                                                                                 ...................... ',
          italic:    '                     ..........                                                      ...................... ',
          underline: '                                                    ..........                       ...................... ',
        },
        {
          text:          'Strike through (ctrl+enter)!',
          children: [ {
            text:          'Try using it for todo lists',
            strikethrough: '...........................',
          } ],
        },
      ] },
    ] },
    { text: 'Vim features', collapsed: true, children: [
      { text: 'Most of vim\'s movement commands', collapsed: true, children: [
        'h, j, k, and l',
        '$ and 0',
        'b, e, w, B, E, W',
        'f, t, F, T',
        { text: 'Some extras', children: [
          '{ and } navigate between siblings',
          'gp navigates to the parent bullet',
        ] },
      ] },
      { text: 'Many of vim\'s operators', collapsed: true, children: [
        'd to delete, c to change',
        'x to delete a character, s to change it',
        'r to replace',
        'y to yank, p and P to paste',
        'J to join lines',
        {text: 'g to go places', children: [
          'g to go to the beginning of the visible document (just G to go to the end)',
          'p to go to the parent of the current line',
          'm to go to a @mark',
        ] },
      ] },
      '. to repeat the last command',
      'Macros! q and @, just like in vim',
      { text: 'Modal editing', collapsed: true, children: [
        { text: 'Insert mode', collapsed: true, children: [
          '... so that you can edit things!',
          'All the different vim ways to enter it: a, A, i, I, o, O',
          'esc or ctrl+c to exit',
        ] },
        { text: 'Visual mode', collapsed: true, children: [
          'Press v to enter visual mode',
          'It only works on one line, for now',
          'It lets you yank (y), delete (d or x) and change (c)',
        ] },
        { text: 'Visual line mode', collapsed: true, children: [
          'Press V to enter visual line mode',
          'It lets you yank (y), delete (d or x), change (c), and indent (< or >) groups of siblings',
        ] },
      ] },
      { text: 'Full history within a session', collapsed: true, children: [
        'Use u to undo and ctrl+r to redo',
        'And use . to repeat the last command',
        'You can define and use macros, just like in vim',
        'ctrl+o and ctrl+i will cycle backwards and forwards through your zoom/jump history',
      ] },
    ] },
    { text: 'Search', collapsed: true, children: [
      'Press / to start searching, and then just type what you want to find',
      'ctrl+j and ctrl+k to page through the results',
      'enter to select what you want, and esc to cancel',
    ] },
    { text: 'Marks', plugins: { mark: 'mark' }, collapsed: true, children: [
      { text: 'I am marked!', plugins: { mark: 'im_a_mark' }, children: [] },
      'Press m to start marking a line, and enter to finish',
      'Use ` or \' to jump to marks',
      { text: 'Tag marks by typing @[markname], like this:  @im_a_mark', children: [
        'Click the tag to jump to the marked location',
        'Alternatively, when your cursor is over the tag, type gm to jump to the mark',
      ] },
      'Delete marks by using dm, or just mark with empty string',
    ] },
    { text: 'Cloning', collapsed: true, children: [
      { text: 'I am a clone!  Try editing me', id: 1 },
      { text: 'Clones can\'t be siblings of each other', children: [
        { clone: 1 },
      ] },
      'And clones can\'t be descendants of each other',
      'Make new clones with yc',
    ] },
    { text: 'Customizability', collapsed: true, children: [
      { text: 'Plugins system', collapsed: true, children: [
        { text: 'See the settings menu to turn on some plugins!', children: [
          { text: 'Easy motion', collapsed: true, children: [
            'Hit space to jump to a row quickly',
            'Based on https://github.com/easymotion/vim-easymotion',
          ] },
          { text: 'Timing', collapsed: true, children: [
            'Keep track of how long you\'ve spent on various bullets',
          ] },
          'Marks is actually written as a plugin, too!  It\'s on by default, but you can turn it off from the settings menu',
        ] },
        'You can write your own plugins too!  ' +
        'See here for documentation: https://github.com/WuTheFWasThat/vimflowy/blob/master/docs/plugins.md (visit links with gx)',
      ] },
      'Customizable hotkeys (via downloading/uploading a json file)',
      'Different color themes (see Settings)',
    ] },
  ] },
  { text: 'Data', collapsed: true, children: [
    'As a user of Vimflowy, you are in full control of your data',
    'Vimflowy was designed to be agnostic to the storage backend',
    'To manage data, visit the Settings menu',
    {
      text: 'By default, all data is entirely local (under the hood, we use localStorage)',
      children: [
        'Your data is never sent over the internet',
        'Vimflowy works offline',
        'Each device (in fact, each browser) will have its own documents',
        {
          text: 'Data is not backed up',
          bold: '        .............',
        },
        'If you clear localStorage, you will lose your data!',
        'If you plan to have a (very!) large document, use a browser with large localStorage limits (Firefox, for example)',
      ],
    },
    {
      text: 'Remote data storage is supported',
      children: [
        'This allows access from multiple browsers/devices',
        'However, there is no support for offline editing',
        {
          text: 'Currently, the only remote backing data storage that has been implemented is Firebase',
          children: [
            'See the settings menu to set this up',
          ],
        },
        'Please contact the dev team if you are interested in other storage backings',
        'They are relatively easy to add!',
      ],
    },
    { text: 'Importing and exporting data', children: [
      {
        text: 'Two import and export formats are supported:',
        children: [
          {
            text: 'JSON (recommended)',
            children: [
              'Export/import preserves all content',
            ],
          },
          {
            text: 'Workflowy-compatible',
            children: [
              'Compatible with Workflowy\'s plaintext export/import',
              'Doesn\'t preserve some Workflowy features, e.g. tags, fonts, etc.',
              'Doesn\'t preserve Vimflowy marks/clones',
            ],
          },
        ],
      },
      'You can regularly export your data in JSON format, as a form of backup',
    ] },
  ] },
  { text: 'Tips', collapsed: true, children: [
    'Collapse things often to avoid clutter.  Zoom into collapsed bullets',
    'Use ctrl+[hjkl] to move blocks of content around easily',
    'Use ? to hide the keybindings menu, once you become an expert',
    'Multiple documents.  Just add the query parameter ?doc=<documentname>',
  ] },
  'Press i to enter insert mode and start adding your own content!',
  'For more info, visit https://github.com/WuTheFWasThat/vimflowy',
];
