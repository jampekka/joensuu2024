(() => {
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };

  // prese.coffee
  var require_prese = __commonJS({
    "prese.coffee"(exports) {
      (function() {
        var win;
        if (nw) {
          win = nw.Window.get();
          nw.App.registerGlobalHotKey(new nw.Shortcut({
            key: "F11",
            active: function() {
              return win.toggleFullscreen();
            }
          }));
          nw.App.registerGlobalHotKey(new nw.Shortcut({
            key: "ctrl+r",
            active: function() {
              return win.reloadIgnoringCache();
            }
          }));
        }
      }).call(exports);
    }
  });
  require_prese();
})();
//# sourceMappingURL=prese.js.map
