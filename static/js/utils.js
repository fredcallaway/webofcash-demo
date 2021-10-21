// Generated by CoffeeScript 2.2.2
var assert, check, checkObj, checkWindowSize, converter, deepLoadJson, deepMap, delay, getTime, loadJson, mapObject, markdown, maybeJson, mean, sleep, zip;

converter = new showdown.Converter();

markdown = function(txt) {
  return converter.makeHtml(txt);
};

getTime = function() {
  return (new Date).getTime();
};


function updateExisting(target, src) {
  Object.keys(target)
        .forEach(k => target[k] = (src.hasOwnProperty(k) ? src[k] : target[k]));
}
;

maybeJson = function(s) {
  try {
    return JSON.parse(s);
  } catch (error) {
    return s;
  }
};

loadJson = function(file) {
  var result;
  result = $.ajax({
    dataType: 'json',
    url: file,
    async: false
  });
  if (result.responseJSON == null) {
    throw new Error(`Could not load ${file}`);
  }
  return result.responseJSON;
};

// because the order of arguments of setTimeout is awful.
delay = function(time, func) {
  return setTimeout(func, time);
};

zip = function(...rows) {
  return rows[0].map(function(_, c) {
    return rows.map(function(row) {
      return row[c];
    });
  });
};

check = function(name, val) {
  if (val === void 0) {
    throw new Error(`${name}is undefined`);
  }
  return val;
};

sleep = function(ms) {
  return new Promise(function(resolve) {
    return window.setTimeout(resolve, ms);
  });
};

mean = function(xs) {
  return (xs.reduce((function(acc, x) {
    return acc + x;
  }))) / xs.length;
};

checkObj = function(obj, keys) {
  var i, k, len;
  if (keys == null) {
    keys = Object.keys(obj);
  }
  for (i = 0, len = keys.length; i < len; i++) {
    k = keys[i];
    if (obj[k] === void 0) {
      console.log('Bad Object: ', obj);
      throw new Error(`${k} is undefined`);
    }
  }
  return obj;
};

assert = function(val) {
  if (!val) {
    throw new Error('Assertion Error');
  }
  return val;
};

checkWindowSize = function(width, height, display) {
  var maxHeight, win_width;
  win_width = $(window).width();
  maxHeight = $(window).height();
  if ($(window).width() < width || $(window).height() < height) {
    display.hide();
    return $('#window_error').show();
  } else {
    $('#window_error').hide();
    return display.show();
  }
};

mapObject = function(obj, fn) {
  return Object.keys(obj).reduce(function(res, key) {
    res[key] = fn(obj[key]);
    return res;
  }, {});
};

deepMap = function(obj, fn) {
  var deepMapper;
  deepMapper = function(val) {
    if (typeof val === 'object') {
      return deepMap(val, fn);
    } else {
      return fn(val);
    }
  };
  if (Array.isArray(obj)) {
    return obj.map(deepMapper);
  }
  if (typeof obj === 'object') {
    return mapObject(obj, deepMapper);
  } else {
    return obj;
  }
};

deepLoadJson = function(file) {
  var replaceFileName;
  replaceFileName = function(f) {
    var o;
    if (typeof f === 'string' && f.endsWith('.json')) {
      o = loadJson(f);
      o._json = f;
      return o;
    } else {
      return f;
    }
  };
  return deepMap(loadJson(file), replaceFileName);
};
