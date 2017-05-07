import * as $ from 'jquery';
import * as _ from 'lodash';

// needed for the browser checks
declare var window: any;

export function id<T>(x: T): T { return x; }

// Helpers to build up regex that finds the start of a word
// Ignore the groups, for the sake of matching (TODO: do that in the caller?)
//
// Allow whitespace or beginning of line, then open paren
export const silentWordStartRegex = '(?:\\s|^)(?:\\()*';
// Allow end parens, punctuation, then whitespace or end of line
export const silentWordEndRegex = '(?:\\))*(?:\\.|,|!|\\?|\\:|\\;)*(?:\\s|$)';

// Returns regex whose first match is a "word" with certain properties (according to a regex string).
// Note the word needn't be a word in the sense of containing no whitespace - that is up to the regex_str to decide.
// It just needs to start on something like a word-start and end on something like a word-end.
export function matchWordRegex(regex_str: string) {
  return new RegExp(silentWordStartRegex + '(' + regex_str + ')' + silentWordEndRegex);
}

// gets slice of an array, *inclusive*
export function getSlice<T>(array: Array<T>, min: number, max: number): Array<T> {
  if (max === -1) {
    if (array.length === 0) {
      return [];
    }
    max = array.length - 1;
  }
  return array.slice(min, max + 1);
}

// NOTE: fn should not have side effects,
// since we parallelize the calls
export async function asyncFilter<T>(
  arr: Array<T>, fn: (el: T) => Promise<boolean>
) {
  const result: Array<{ el: T, i: number }> = [];
  await Promise.all(
    arr.map(async (el, i) => {
      if (await fn(el)) {
        result.push({ el, i });
      }
    })
  );
  return _.sortBy(result, (x) => x.i).map((x) => x.el);
}

export function promiseDebounce(fn: (...args: Array<any>) => Promise<void>) {
  let running = false;
  let pending = false;
  const run = (...args: Array<any>) => {
    running = true;
    fn(...args).then(() => {
      if (pending) {
        pending = false;
        run(...args);
      } else {
        running = false;
      }
    });
  };
  return (...args: Array<any>) => {
    if (!running) {
      run(...args);
    } else {
      pending = true;
    }
  };
};

// TODO: is quite silly to consider undefined as whitespace...
export function isWhitespace(chr: string | undefined) {
  return (chr === ' ') || (chr === '\n') || (chr === undefined);
}

// NOTE: currently unused
export function isPunctuation(chr: string) {
  return chr === '.' || chr === ',' || chr === '!' || chr === '?';
}

const urlRegex = /^https?:\/\/([^\s]+\.[^\s]+$|localhost)/;
export function isLink(text: string): boolean {
  return urlRegex.test(text);
}

export function mimetypeLookup(filename: string): string | undefined {
  const parts = filename.split('.');
  const extension = parts.length > 1 ? parts[parts.length - 1] : '';
  const extensionLookup: {[key: string]: string} = {
    'json': 'application/json',
    'txt': 'text/plain',
    '': 'text/plain',
  };
  return extensionLookup[extension.toLowerCase()];
}

// TODO: get jquery typing to work?
export function scrollDiv($elem: any, amount: number) {
  // # animate.  seems to not actually be great though
  // $elem.stop().animate({
  //     scrollTop: $elem[0].scrollTop + amount
  // }, 50)
  return $elem.scrollTop($elem.scrollTop() + amount);
}

// TODO: get jquery typing to work?
export function scrollIntoView(el: Element, $within: any, margin: number = 0) {
  const elemTop = el.getBoundingClientRect().top;
  const elemBottom = el.getBoundingClientRect().bottom;

  const top_margin = margin;
  const bottom_margin = margin + $('#bottom-bar').height();

  if (elemTop < top_margin) {
    // scroll up
    return scrollDiv($within, elemTop - top_margin);
  } else if (elemBottom > window.innerHeight - bottom_margin) {
    // scroll down
    return scrollDiv($within, elemBottom - window.innerHeight + bottom_margin);
  }
}

export function isScrolledIntoView(elem: any, container: any) {
  const $elem = $(elem);
  const $container = $(container);

  const docViewTop = $container.offset().top;
  const docViewBottom = docViewTop + $container.outerHeight();

  const elemTop = $elem.offset().top;
  const elemBottom = elemTop + $elem.height();

  return ((elemBottom <= docViewBottom) && (elemTop >= docViewTop));
}

export function getParameterByName(name: string) {
  name = name.replace(/[\[\]]/g, '\\$&');
  const regex = new RegExp('[?&]' + name + '(=([^&#]*)|&|#|$)');
  const results = regex.exec(window.location.href);
  if (!results) { return null; }
  if (!results[2]) { return ''; }
  return decodeURIComponent(results[2].replace(/\+/g, ' '));
}

export function downloadFile(filename: string, content: string, mimetype: string) {
  const exportDiv = $('<a>').addClass('hidden').appendTo($('body'));
  exportDiv.attr('download', filename);
  exportDiv.attr('href', `data: ${mimetype};charset=utf-8,${encodeURIComponent(content)}`);
  exportDiv[0].click();
  exportDiv.attr('download', null as any);
  exportDiv.attr('href', null as any);
  exportDiv.remove();
}

export async function timeout(ns: number) {
  await new Promise((resolve) => setTimeout(resolve, ns));
}

// SEE: http://stackoverflow.com/questions/9847580/how-to-detect-safari-chrome-ie-firefox-and-opera-browser
export function isOpera(): boolean {
  return !!window.opera || navigator.userAgent.indexOf(' OPR/') >= 0; // Opera 8.0+
}
export function isSafari(): boolean {
  return Object.prototype.toString.call(window.HTMLElement).indexOf('Constructor') > 0; // Safari 3+
}
export function isChrome(): boolean {
  return !!window.chrome && !isOpera; // Chrome 1+
}
declare var InstallTrigger: any;
export function isFirefox(): boolean {
  return typeof InstallTrigger !== 'undefined'; // Firefox 1.0+
}

export function cancel(ev: Event) {
  ev.stopPropagation();
  ev.preventDefault();
  return false;
}

