var n={};!function(t){var r={bytesToString:function(n){return n.map((function(n){return String.fromCharCode(n)})).join("")},stringToBytes:function(n){return n.split("").map((function(n){return n.charCodeAt(0)}))}};r.UTF8={bytesToString:function(n){return decodeURIComponent(escape(r.bytesToString(n)))},stringToBytes:function(n){return r.stringToBytes(unescape(encodeURIComponent(n)))}};n?n=r:t.convertString=r}(n);var t=n;export default t;
