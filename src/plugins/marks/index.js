import React from 'react';

import * as Plugins from '../../assets/js/plugins';
import Menu from '../../assets/js/menu';
import * as Modes from '../../assets/js/modes';
import * as DataStore from '../../assets/js/datastore';
import Document from '../../assets/js/document';
import Session from '../../assets/js/session';
import LineComponent from '../../assets/js/components/line';
import Mutation from '../../assets/js/mutations';
import * as errors from '../../assets/js/errors';
import * as constants from '../../assets/js/constants';

import * as basic_defs from '../../assets/js/definitions/basics';

// NOTE: mark mode is still in the core code
// TODO: separate that out too?

const markStyle = {
  padding: '0px 10px',
  marginRight: 10,
  borderRadius: 6,
};

class MarksPlugin {
  constructor(api) {
    this.api = api;
  }

  async enable() {
    this.logger = this.api.logger;
    this.session = this.api.session;
    this.document = this.session.document;
    const that = this;

    class SetMark extends Mutation {
      constructor(row, mark) {
        super();
        this.row = row;
        this.mark = mark;
      }
      str() {
        return `row ${this.row}, mark ${this.mark}`;
      }
      async mutate(/* session */) {
        return await that._setMark(this.row, this.mark);
      }
      async rewind(/* session */) {
        return [
          /* eslint-disable no-use-before-define */
          new UnsetMark(this.row)
          /* eslint-enable no-use-before-define */
        ];
      }
    }
    this.SetMark = SetMark;

    class UnsetMark extends Mutation {
      constructor(row) {
        super();
        this.row = row;
      }
      str() {
        return `row ${this.row}`;
      }
      async mutate(/* session */) {
        this.mark = await that._getMark(this.row);
        return await that._unsetMark(this.row, this.mark);
      }
      async rewind(/* session */) {
        return [
          new SetMark(this.row, this.mark)
        ];
      }
    }
    this.UnsetMark = UnsetMark;

    // Serialization #

    this.api.registerHook('document', 'serializeRow', async (struct, info) => {
      const mark = await this._getMark(info.row);
      if (mark) {
        struct.mark = mark;
      }
      return struct;
    });

    this.api.registerListener('document', 'loadRow', async (path, serialized) => {
      if (serialized.mark) {
        const err = await this.updateMark(path.row, serialized.mark);
        if (err) { return this.session.showMessage(err, {text_class: 'error'}); }
      }
    });

    // Commands #

    const MODES = Modes.modes;

    this.marksession = null;
    this.marksessionpath = null;

    this.api.registerMode({
      name: 'MARK',
      hotkey_type: Modes.HotkeyType.INSERT_MODE_TYPE,
      within_row: true,
      enter: async (session /*, newMode?: ModeId */) => {
        // initialize marks stuff
        const doc = new Document(new DataStore.InMemory());
        await doc.load(constants.empty_data);
        this.marksession = new Session(doc);
        await this.marksession.setMode(MODES.INSERT);
        this.marksessionpath = session.cursor.path;
      },
      exit: async (/*session, newMode?: ModeId */) => {
        this.marksession = null;
        this.marksessionpath = null;
      },
      key_transforms: [
        async (key, context) => {
          // must be non-whitespace
          if (key.length === 1) {
            if (/^\S*$/.test(key)) {
              await this.marksession.addCharsAtCursor([{char: key}]);
              return [null, context];
            }
          }
          return [key, context];
        }
      ]
    });

    const CMD_MARK = this.api.registerCommand({
      name: 'MARK',
      default_hotkeys: {
        normal_like: ['m']
      }
    });
    this.api.registerAction([MODES.NORMAL], CMD_MARK, {
      description: 'Mark a line',
    }, async function() {
      await this.session.setMode(MODES.MARK);
    });

    const CMD_FINISH_MARK = this.api.registerCommand({
      name: 'FINISH_MARK',
      default_hotkeys: {
        insert_like: ['enter']
      }
    });
    this.api.registerAction([MODES.MARK], CMD_FINISH_MARK, {
      description: 'Finish typing mark',
    }, async function() {
      const mark = await that.marksession.curText();
      const err = await that.updateMark(that.marksessionpath.row, mark);
      if (err) { this.session.showMessage(err, {text_class: 'error'}); }
      await this.session.setMode(MODES.NORMAL);
      this.keyStream.save();
    });

    const CMD_GO = this.api.commands.GO;
    this.api.registerMotion([CMD_GO, CMD_MARK], {
      description: 'Go to the mark indicated by the cursor, if it exists',
    }, async function() {
      return async cursor => {
        const word = await this.session.document.getWord(cursor.row, cursor.col);
        if (word.length < 1 || word[0] !== '@') {
          return false;
        }
        const mark = word.slice(1);
        const allMarks = await that.listMarks();
        if (mark in allMarks) {
          const row = allMarks[mark];
          const path = await this.session.document.canonicalPath(row);
          await this.session.zoomInto(path);
          return true;
        } else {
          return false;
        }
      };
    });

    const CMD_DELETE = this.api.commands.DELETE;
    this.api.registerAction([MODES.NORMAL], [CMD_DELETE, CMD_MARK], {
      description: 'Delete mark at cursor'
    }, async function() {
      const err = await that.updateMark(this.session.cursor.row, '');
      if (err) { this.session.showMessage(err, {text_class: 'error'}); }
      this.keyStream.save();
    });

    const CMD_MARK_SEARCH = this.api.registerCommand({
      name: 'MARK_SEARCH',
      default_hotkeys: {
        normal_like: ['\'', '`']
      }
    });
    this.api.registerAction([MODES.NORMAL], CMD_MARK_SEARCH, {
      description: 'Go to (search for) a mark',
    }, async function() {
      await this.session.setMode(MODES.SEARCH);
      this.session.menu = new Menu(async (text) => {
        // find marks that start with the prefix
        const findMarks = async (document, prefix, nresults = 10) => {
          const marks = await that.listMarks();
          const results = []; // list of paths
          for (const mark in marks) {
            const row = marks[mark];
            if (mark.indexOf(prefix) === 0) {
              const path = await this.session.document.canonicalPath(row);
              results.push({ path, mark });
              if (nresults > 0 && results.length === nresults) {
                break;
              }
            }
          }
          return results;
        };

        return await Promise.all(
          (await findMarks(this.session.document, text)).map(
            async ({ path, mark }) => {
              const line = await this.session.document.getLine(path.row);
              return {
                contents: line,
                renderHook(line) {
                  return [
                    <span key={`mark_${mark}`} style={markStyle}
                          className='theme-bg-secondary theme-trim'>
                      {mark}
                    </span>
                    ,
                    line
                  ];
                },
                fn: async () => await this.session.zoomInto(path)
              };
            }
          )
        );
      });
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_MOTION, {
      description: 'Move the cursor',
    }, async function(motion) {
      await motion(that.marksession.cursor, {pastEnd: true});
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_DELETE_LAST_CHAR, {
      description: 'Delete last character (i.e. backspace key)',
    }, async function() {
      await that.marksession.deleteAtCursor();
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_DELETE_CHAR, {
      description: 'Delete character at the cursor (i.e. del key)',
    }, async function() {
      await this.session.marksession.delCharsAfterCursor(1);
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_HELP, {
      description: 'Show/hide key bindings (edit in settings)',
    }, async function() { // eslint-disable-line require-yield
      this.session.toggleBindingsDiv();
      this.keyStream.forget(1);
    });

    this.api.registerAction([MODES.MARK], basic_defs.CMD_EXIT_MODE, {
      description: 'Exit back to normal mode',
    }, async function() {
      await this.session.setMode(MODES.NORMAL);
      this.keyStream.forget();
    });

    this.api.registerHook('document', 'pluginPathContents', async (obj, { path }) => {
      const mark = await this._getMark(path.row);

      const marking = this.marksessionpath && this.marksessionpath.is(path);

      obj.marks = { mark, marking };

      if (marking) {
        obj.marks.markText = await this.marksession.document.getLine(
          this.marksession.cursor.path.row
        );
        obj.marks.markCol = this.marksession.cursor.col;
      }
      return obj;
    });

    this.api.registerHook('document', 'pluginPathContentsSync', (obj, { path }) => {
      const mark = this._getMarkSync(path.row);
      if (mark === null) {
        obj.marks = null;
        return obj;
      }

      const marking = this.marksessionpath && this.marksessionpath.is(path);

      obj.marks = { mark, marking };

      if (marking) {
        // NOTE: marksession is always in-memory so no need for null check
        obj.marks.markText = this.marksession.document.store.getLineSync(
          this.marksession.cursor.path.row
        );
        obj.marks.markCol = this.marksession.cursor.col;
      }
      return obj;
    });

    this.api.registerHook('session', 'renderLineOptions', (options, info) => {
      if (info.pluginData.marks && info.pluginData.marks.marking) {
        options.cursors = {};
      }
      return options;
    });

    this.api.registerHook('session', 'renderLineContents', (lineContents, info) => {
      const { pluginData } = info;
      if (pluginData.marks) {
        if (pluginData.marks.marking) {
          lineContents.unshift(
            <span style={markStyle} key='mark'
                  className='theme-bg-secondary theme-trim-accent'>
              <LineComponent
                lineData={pluginData.marks.markText}
                cursors={{
                  [pluginData.marks.markCol]: true
                }}
                cursorBetween={true}
              />
            </span>
          );
        } else {
          const mark = pluginData.marks.mark;
          if (mark) {
            lineContents.unshift(
              <span style={markStyle} key='mark' className='theme-bg-secondary theme-trim'>
                {mark}
              </span>
            );
          }
        }
      }
      return lineContents;
    });

    this.api.registerHook('session', 'renderLineWordHook', (line, info) => {
      const { wordInfo } = info;

      if (this.session.mode === MODES.NORMAL) {
        if (wordInfo.word[0] === '@') {
          const mark = wordInfo.word.slice(1);
          const path = this.marks_to_paths[mark];
          if (path) {
            for (let i = wordInfo.start; i <= wordInfo.end; i++) {
              line[i].renderOptions.type = 'a';
              line[i].renderOptions.onClick = async () => {
                await this.session.zoomInto(path);
                this.session.save();
              };
            }
          }
        }
      }
      return line;
    });

    this.api.registerListener('document', 'afterDetach', async () => {
      await this.computeMarksToPaths();
    });
    await this.computeMarksToPaths();

  }

  // maintain global marks data structures
  //   a map: row -> mark
  //   and a second map: mark -> row
  async _getRowsToMarks() {
    return await this.api.getData('ids_to_marks', {});
  }
  _getRowsToMarksSync() {
    return this.api.getDataSync('ids_to_marks');
  }
  async _setRowsToMarks(rows_to_marks) {
    return await this.api.setData('ids_to_marks', rows_to_marks);
  }
  async _getMarksToRows() {
    return await this.api.getData('marks_to_ids', {});
  }
  async _setMarksToRows(mark_to_rows) {
    return await this.api.setData('marks_to_ids', mark_to_rows);
  }

  async _sanityCheckMarks() {
    const marks_to_rows = await this._getMarksToRows();
    const rows_to_marks = await this._getRowsToMarks();
    const marks_to_rows2 = {};
    for (const row in rows_to_marks) {
      const mark = rows_to_marks[row];
      marks_to_rows2[mark] = parseInt(row);
    }
    errors.assert_deep_equals(marks_to_rows, marks_to_rows2, 'Inconsistent rows_to_marks');
  }

  // get mark for an row, '' if it doesn't exist
  async _getMark(row) {
    const marks = await this._getRowsToMarks();
    return marks[row] || '';
  }

  _getMarkSync(row) {
    const marks = this._getRowsToMarksSync();
    if (marks === null) {
      return null;
    }
    return marks[row] || '';
  }

  async _setMark(row, mark) {
    await this._sanityCheckMarks();
    const marks_to_rows = await this._getMarksToRows();
    const rows_to_marks = await this._getRowsToMarks();
    errors.assert(!marks_to_rows.hasOwnProperty(mark));
    errors.assert(!rows_to_marks.hasOwnProperty(row));
    marks_to_rows[mark] = row;
    rows_to_marks[row] = mark;
    await this._setMarksToRows(marks_to_rows);
    await this._setRowsToMarks(rows_to_marks);
    await this._sanityCheckMarks();
    await this.computeMarksToPaths();
  }

  async _unsetMark(row, mark) {
    await this._sanityCheckMarks();
    const marks_to_rows = await this._getMarksToRows();
    const rows_to_marks = await this._getRowsToMarks();
    errors.assert_equals(marks_to_rows[mark], row);
    errors.assert_equals(rows_to_marks[row], mark);
    delete marks_to_rows[mark];
    delete rows_to_marks[row];
    await this._setMarksToRows(marks_to_rows);
    await this._setRowsToMarks(rows_to_marks);
    await this._sanityCheckMarks();
    await this.computeMarksToPaths();
  }

  // compute set of paths, used for rendering
  async computeMarksToPaths() {
    await this._sanityCheckMarks();
    // note: some of these may be detached
    const marks_to_rows = await this._getMarksToRows();
    const marks_to_paths = {};
    for (const mark in marks_to_rows) {
      const row = marks_to_rows[mark];
      // if (await this.document.isAttached(row)) {
      const path = await this.session.document.canonicalPath(row);
      if (path == null) {
        continue;
      }
      // errors.assert(path !== null);
      marks_to_paths[mark] = path;
    }
    this.marks_to_paths = marks_to_paths;
  }

  async listMarks() {
    await this._sanityCheckMarks();
    const marks_to_rows = await this._getMarksToRows();

    const all_marks = {};
    for (const mark in marks_to_rows) {
      const row = marks_to_rows[mark];
      if (await this.document.isAttached(row)) {
        all_marks[mark] = row;
      }
    }
    return all_marks;
  }

  // Set the mark for row
  // Returns whether setting mark succeeded
  async updateMark(row, mark = '') {
    const marks_to_rows = await this._getMarksToRows();
    const rows_to_marks = await this._getRowsToMarks();
    const oldmark = rows_to_marks[row];

    if (!(oldmark || mark)) {
      return 'No mark to delete!';
    }

    if (mark in marks_to_rows) {
      if (marks_to_rows[mark] === row) {
        return 'Already marked, nothing to do!';
      }

      const other_row = marks_to_rows[mark];
      if (await this.document.isAttached(other_row)) {
        return `Mark '${mark}' was already taken!`;
      } else {
        await this.session.do(new this.UnsetMark(other_row, mark));
      }
    }

    if (oldmark) {
      await this.session.do(new this.UnsetMark(row, oldmark));
    }

    if (mark) {
      await this.session.do(new this.SetMark(row, mark));
    }

    return null;
  }
}

// NOTE: because listing marks filters, disabling is okay

const pluginName = 'Marks';

Plugins.register(
  {
    name: pluginName,
    author: 'Jeff Wu',
    description:
      `Lets you tag a row with a string, and then reference that row with @markname.
  Fast search for marked rows, using '.`
  },
  async (api) => {
    const marksPlugin = new MarksPlugin(api);
    await marksPlugin.enable();
    return marksPlugin;
  },
  async (api) => {
    api.deregisterAll();
  },
);

export { pluginName };
