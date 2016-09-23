/*
Represents user settings
Uses a datastore key which is agnostic to which document is being viewed
(i.e. /blah and /blah2 have the same settings)
*/

import DataStore from './datastore';

const default_settings = {
  theme: 'default-theme',
  showKeyBindings: true,
  hotkeys: {},
};

export default class Settings {
  private datastore: DataStore;

  constructor(datastore) {
    this.datastore = datastore;

    return null;
  }

  public async getSetting(setting) {
    return await this.datastore.getSetting(setting, default_settings[setting]);
  }

  public async setSetting(setting, value) {
    return await this.datastore.setSetting(setting, value);
  }
}
