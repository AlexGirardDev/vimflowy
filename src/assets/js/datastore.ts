/* globals alert, localStorage */
import * as firebase from 'firebase';

import * as _ from 'lodash';
import * as Immutable from 'immutable';

import * as constants from './constants';
import * as errors from './errors';
import logger from './logger';

import { Line, Row, SerializedPath, MacroMap } from './types';

/*
DataStore abstracts the data layer, so that it can be swapped out.
There are many methods the each type of DataStore should implement to satisfy the API.
However, in the case of a key-value store, one can simply implement `get` and `set` methods.
Currently, DataStore has a synchronous API.  This may need to change eventually...  :(
*/

const timeout = (ns) => {
  return new Promise((resolve) => {
    setTimeout(resolve, ns);
  });
};
// const simulateDelay = 10;
// const simulateDelay = 1;
const simulateDelay = 0;

export default class DataStore {
  protected prefix: string;

  constructor(prefix = '') {
    this.prefix = `${prefix}save`;
  }

  protected _lineKey_(row: Row): string {
    return `${this.prefix}:${row}:line`;
  }
  protected _parentsKey_(row: Row): string {
    return `${this.prefix}:${row}:parent`;
  }
  protected _childrenKey_(row: Row): string {
    return `${this.prefix}:${row}:children`;
  }
  protected _detachedChildrenKey_(row: Row): string {
    return `${this.prefix}:${row}:detached_children`;
  }
  protected _detachedParentKey_(row: Row): string {
    return `${this.prefix}:${row}:detached_parent`;
  }
  protected _collapsedKey_(row: Row): string {
    return `${this.prefix}:${row}:collapsed`;
  }

  protected _pluginDataKey_(plugin: string, key: string): string {
    return `${this.prefix}:plugin:${plugin}:data:${key}`;
  }

  // no prefix, meaning it's global
  protected _settingKey_(setting): string {
    return `settings:${setting}`;
  }

  protected _lastSaveKey_(): string {
    return `${this.prefix}:lastSave`;
  }
  protected _lastViewrootKey_(): string {
    return `${this.prefix}:lastviewroot2`;
  }
  protected _macrosKey_(): string {
    return `${this.prefix}:macros`;
  }

  protected async _get(key: string, default_value: any = undefined): Promise<any> {
    throw new errors.NotImplemented();
  }

  protected async _set(key: string, value: any): Promise<void> {
    throw new errors.NotImplemented();
  }

  // get and set values for a given row
  public async getLine(row: Row): Promise<Line> {
    return (await this._get(this._lineKey_(row), [])).map(function(obj) {
      if (typeof obj === 'string') {
        obj = { char: obj };
      }
      return obj;
    });
  }
  public async setLine(row: Row, line: Line): Promise<void> {
    return await this._set(this._lineKey_(row), line.map(function(obj) {
      // if no properties are true, serialize just the character to save space
      if (_.every(constants.text_properties.map(property => !obj[property]))) {
        return obj.char;
      } else {
        return obj;
      }
    }));
  }

  public async getParents(row: Row): Promise<Array<Row>> {
    let parents = await this._get(this._parentsKey_(row), []);
    if (typeof parents === 'number') {
      parents = [ parents ];
    }
    return parents;
  }
  public async setParents(row: Row, parents: Array<Row>): Promise<void> {
    return await this._set(this._parentsKey_(row), parents);
  }

  public async getChildren(row: Row): Promise<Array<Row>> {
    return await this._get(this._childrenKey_(row), []);
  }
  public async setChildren(row: Row, children: Array<Row>): Promise<void> {
    return await this._set(this._childrenKey_(row), children);
  }

  public async getDetachedParent(row: Row): Promise<Row> {
    return await this._get(this._detachedParentKey_(row), null);
  }
  public async setDetachedParent(row: Row, parent: Row): Promise<void> {
    return await this._set(this._detachedParentKey_(row), parent);
  }

  public async getDetachedChildren(row: Row): Promise<Array<Row>> {
    return await this._get(this._detachedChildrenKey_(row), []);
  }
  public async setDetachedChildren(row: Row, children: Array<Row>): Promise<void> {
    return await this._set(this._detachedChildrenKey_(row), children);
  }

  public async getCollapsed(row: Row): Promise<boolean> {
    return await this._get(this._collapsedKey_(row));
  }
  public async setCollapsed(row: Row, collapsed: boolean): Promise<void> {
    return await this._set(this._collapsedKey_(row), collapsed || false);
  }

  // get mapping of macro_key -> macro
  public async getMacros(): Promise<MacroMap> {
    return await this._get(this._macrosKey_(), {});
  }

  // set mapping of macro_key -> macro
  public async setMacros(macros: MacroMap): Promise<void> {
    return await this._set(this._macrosKey_(), macros);
  }

  // get global settings (data not specific to a document)
  public async getSetting(
    setting: string, default_value: any = undefined
  ): Promise<any> {
    return await this._get(this._settingKey_(setting), default_value);
  }
  public async setSetting(setting: string, value: any): Promise<void> {
    return await this._set(this._settingKey_(setting), value);
  }

  // get last view (for page reload)
  public async setLastViewRoot(ancestry: SerializedPath): Promise<void> {
    await this._set(this._lastViewrootKey_(), ancestry);
  }
  public async getLastViewRoot(): Promise<SerializedPath> {
    return await this._get(this._lastViewrootKey_(), []);
  }

  public async setPluginData(
    plugin: string, key: string, data: any
  ): Promise<void> {
    await this._set(this._pluginDataKey_(plugin, key), data);
  }
  public async getPluginData(
    plugin: string, key: string, default_value: any = undefined
  ): Promise<any> {
    return await this._get(this._pluginDataKey_(plugin, key), default_value);
  }

  // get next row ID
  // public so test case can override
  public async getId(): Promise<number> {
    // suggest to override this for efficiency
    let id = 1;
    while ((await this._get(this._lineKey_(id), null)) !== null) {
      id++;
    }
    return id;
  }

  public async getNew() {
    const id = await this.getId();
    await Promise.all([
      this.setLine(id, []),
      this.setChildren(id, []),
      this.setCollapsed(id, false),
    ]);
    return id;
  }
}

export class CachingDataStore extends DataStore {
  private cache: Immutable.Map<string, any>;

  constructor(prefix = '') {
    super(prefix);
    this.cache = Immutable.Map({});
  }

  protected async _get(key: string, default_value: any = undefined): Promise<any> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }
    if (this.cache.has(key)) {
      return _.cloneDeep(this.cache.get(key));
    } else {
      const value = await this._getUncached(key, default_value);
      this.cache = this.cache.set(key, value);
      return value;
    }
  }

  protected async _set(key: string, value: any): Promise<void> {
    if (simulateDelay) { await timeout(simulateDelay * Math.random()); }
    await this._setUncached(key, value);
    this.cache = this.cache.set(key, value);
  }

  protected async _getUncached(key: string, default_value: any = undefined): Promise<any> {
    throw new errors.NotImplemented();
  }

  protected async _setUncached(key: string, value: any): Promise<void> {
    throw new errors.NotImplemented();
  }

  // private _getSync<T>(key: string, transform?: (value: any) => T): T {
  private _getSync(key: string, transform?: (value: any) => any): any {
    if (!this.cache.has(key)) { return null; }

    let value = this.cache.get(key);
    if (transform) {
      value = transform(value);
    }
    return value;
  }

  public getLineSync(row: Row): Line {
    return this._getSync(this._lineKey_(row), (line) => {
      return line.map(function(obj) {
        if (typeof obj === 'string') {
          obj = { char: obj };
        }
        return obj;
      });
    });
  }

  public getChildrenSync(row: Row): Array<Row> {
    return this._getSync(this._childrenKey_(row));
  }

  public getParentsSync(row: Row): Array<Row> {
    return this._getSync(this._parentsKey_(row), (parents) => {
      if (typeof parents === 'number') {
        parents = [ parents ];
      }
      return parents;
    });
  }

  public getCollapsedSync(row: Row): Boolean {
    return this._getSync(this._collapsedKey_(row));
  }

  public getPluginDataSync(plugin: string, key: string): any {
    return this._getSync(this._pluginDataKey_(plugin, key));
  }
}

export class InMemory extends CachingDataStore {
  constructor() {
    super('');
  }

  protected async _getUncached(key: string, default_value: any = undefined): Promise<any> {
    // no backing store
    return default_value;
  }

  protected async _setUncached(key: string, value: any): Promise<void> {
    // do nothing
  }

}

export class LocalStorageLazy extends CachingDataStore {
  private lastSave: number;
  private trackSaves: boolean;

  constructor(prefix = '', trackSaves = false) {
    super(prefix);
    this.trackSaves = trackSaves;
    if (this.trackSaves) {
      this.lastSave = Date.now();
    }
  }

  private _IDKey_() {
    return `${this.prefix}:lastID`;
  }

  protected async _getUncached(key: string, default_value: any = undefined): Promise<any> {
    return this._getLocalStorage_(key, default_value);
  }

  protected async _setUncached(key: string, value: any): Promise<void> {
    return this._setLocalStorage_(key, value);
  }

  private _setLocalStorage_(
    key: string, value: any,
    options: {doesNotAffectLastSave?: boolean} = {}
  ): void {
    if (this.trackSaves) {
      if (this.getLastSave() > this.lastSave) {
        alert('This document has been modified (in another tab) since opening it in this tab. Please refresh to continue!'
        );
        throw new errors.DataPoisoned('Last save disagrees with cache');
      }

      if (!options.doesNotAffectLastSave) {
        this.lastSave = Date.now();
        localStorage.setItem(this._lastSaveKey_(), this.lastSave + '');
      }
    }

    logger.debug('setting local storage', key, value);
    return localStorage.setItem(key, JSON.stringify(value));
  }

  private _getLocalStorage_(key: string, default_value: any = undefined): any {
    logger.debug('getting from local storage', key, default_value);
    const stored = localStorage.getItem(key);
    if (stored === null) {
      logger.debug('got nothing, defaulting to', default_value);
      return default_value;
    }
    try {
      const val = JSON.parse(stored);
      logger.debug('got ', val);
      return val;
    } catch (error) {
      logger.debug('parse failure:', stored);
      return default_value;
    }
  }

  // determine last time saved (for multiple tab detection)
  // note that this doesn't cache!
  public getLastSave(): number {
    return this._getLocalStorage_(this._lastSaveKey_(), 0);
  }

  public async getId(): Promise<number> {
    let id: number = this._getLocalStorage_(this._IDKey_(), 1);
    while (this._getLocalStorage_(this._lineKey_(id), null) !== null) {
      id++;
    }
    this._setLocalStorage_(this._IDKey_(), id + 1);
    return id;
  }
}

export class FirebaseStore extends CachingDataStore {
  private lastSave: number;
  private fbase: any;
  // private fbase: Firebase;

  constructor(prefix = '', url, apiKey) {
    super(prefix);
    this.fbase = firebase.initializeApp({
      apiKey: apiKey,
      databaseURL: `https://${url}`,
    }).database();
    // this.fbase.authWithCustomToken(token, (err, authdata) => {})
    this.lastSave = Date.now();
  }

  private _IDKey_() {
    return `${this.prefix}:lastID`;
  }

  protected _getUncached(key: string, default_value: any = undefined): Promise<any> {
    return new Promise((resolve, reject) => {
      this.fbase.ref(key).once(
        'value',
        (data) => {
          const exists = data.exists();
          let value = data.val();
          if ((!exists) || (value === null)) {
            value = default_value;
          }
          // default_value
          return resolve(value);
        },
        (err) => {
          return reject(err);
        }
      );
    });
  }

  protected _setUncached(key: string, value: any): Promise<void> {
    this.fbase.ref(key).set(
      value,
      (err) => {
        if (err) { throw err; }
        // else put in promise queue, and notify properly when synced
      }
    );
    return Promise.resolve();
  }

  // NOTE: safe version that doesn't assume caching
  //       it's slow but could possibly be used for multi-user in the future
  // protected _set(key: string, value: any): Promise<void> {
  //   return new Promise((resolve, reject) => {
  //     this.fbase.ref(key).set(
  //       value,
  //       (err) => {
  //         if (err) {
  //           return reject(err);
  //         }
  //         return resolve();
  //       }
  //     );
  //   });
  // }

  // determine last time saved (for multiple tab detection)
  // doesn't cache!
  public getLastSave(): number {
    return 1;
  }

  public async getId(): Promise<number> {
    let id: number = await this._get(this._IDKey_(), 1);
    while ((await this._get(this._lineKey_(id), null)) !== null) {
      id++;
    }
    await this._set(this._IDKey_(), id + 1);
    return id;
  }
}
