/*
Represents user settings
Uses a datastore key which is agnostic to which document is being viewed
(i.e. /blah and /blah2 have the same settings)
*/

const default_settings = {
  theme: 'default-theme',
  showKeyBindings: true,
  hotkeys: {}
};

export default class Settings {

  constructor(datastore, options = {}) {
    this.datastore = datastore;

    this.mainDiv = options.mainDiv;
    this.keybindingsDiv = options.keybindingsDiv;

    for (const setting in default_settings) {
      if (this.getSetting(setting) === null) {
        this.setSetting(setting, default_settings[setting]);
      }
    }
    return null;
  }

  async getSetting(setting, defaultValue = undefined) {
    return await this.datastore.getSetting(setting, defaultValue);
  }

  async setSetting(setting, value) {
    return await this.datastore.setSetting(setting, value);
  }
}
