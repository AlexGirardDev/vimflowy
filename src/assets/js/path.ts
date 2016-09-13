import * as constants from './constants';
import * as errors from './errors';

import { Row } from './types';

// represents a tree-traversal starting from the root going down
// should be immutable
export default class Path {
  public parent: Path;
  public row: Row;

  public static root() {
    return new Path(null, constants.root_row);
  }

  public static loadFromAncestry(ancestry) {
    if (ancestry.length === 0) {
      return Path.root();
    }
    const row = ancestry.pop();
    const parent = Path.loadFromAncestry(ancestry);
    return parent.child(row);
  }

  constructor(parent, row) {
    this.parent = parent;
    this.row = row;
  }

  public isRoot() {
    return this.row === constants.root_row;
  }

  // gets a list of IDs
  public getAncestry() {
    if (this.isRoot()) { return []; }
    const ancestors = this.parent.getAncestry();
    ancestors.push(this.row);
    return ancestors;
  }

  // length() {
  //   if this.parent === null {
  //     return 0;
  //   }
  //   return 1 + this.parent.length();
  // }

  public child(row) {
    errors.assert(row !== this.row);
    return new Path(this, row);
  }

  public isDescendant(other_path) {
    return this.walkFrom(other_path) !== null;
  }

  public walkFrom(ancestor) {
    const my_ancestry = this.getAncestry();
    const their_ancestry = ancestor.getAncestry();
    if (my_ancestry.length < their_ancestry.length) {
      return null;
    }
    for (let i = 0; i < their_ancestry.length; i++) {
      if (my_ancestry[i] !== their_ancestry[i]) {
        return null;
      }
    }
    return my_ancestry.slice(their_ancestry.length);
  }

  public shedUntil(row) {
    let ancestor: Path = this;
    const path = [];
    while (ancestor.row !== row) {
      if (!ancestor.parent) {
        return [null, null];
      }
      path.push(ancestor.row);
      ancestor = ancestor.parent;
    }
    return [path.reverse(), ancestor];
  }

  public extend(walk) {
    let descendent: Path = this;
    walk.forEach((row) => {
      descendent = descendent.child(row);
    });
    return descendent;
  }

  // Represents the exact same row
  public is(other) {
    if (other === undefined) { return false; }
    if (this.row !== other.row) { return false; }
    if (this.isRoot()) { return other.isRoot(); }
    if (other.isRoot()) { return false; }
    return this.parent.is(other.parent);
  }
}
