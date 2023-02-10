/**
 * @typedef Config
 * @property {Boolean} allowNew Allows creation of new tags
 * @property {Boolean} showAllSuggestions Show all suggestions even if they don't match. Disables validation.
 * @property {String} badgeStyle Color of the badge (color can be configured per option as well)
 * @property {Boolean} allowClear Show a clear icon
 * @property {Boolean} clearEnd Place clear icon at the end
 * @property {Array|String} selected A comma separated list of selected values
 * @property {String} regex Regex for new tags
 * @property {Array|String} separator A list (pipe separated) of characters that should act as separator (default is using enter key)
 * @property {Number} max Limit to a maximum of tags (0 = no limit)
 * @property {String} placeholder Provides a placeholder if none are provided as the first empty option
 * @property {String} clearLabel Text as clear tooltip
 * @property {String} searchLabel Default placeholder
 * @property {Boolean} keepOpen Keep suggestions open after selection, clear on focus out
 * @property {Boolean} allowSame Allow same
 * @property {String} baseClass Customize the class applied to badges
 * @property {Boolean} addOnBlur Add new tags on blur (only if allowNew is enabled)
 * @property {Number} suggestionsThreshold Number of chars required to show suggestions
 * @property {Number} maximumItems Maximum number of items to display
 * @property {Boolean} autoselectFirst Always select the first item
 * @property {Boolean} updateOnSelect Update input value on selection (doesn't play nice with autoselectFirst)
 * @property {Boolean} fullWidth Match the width on the input field
 * @property {Boolean} fixed Use fixed positioning (solve overflow issues)
 * @property {String} labelField Key for the label
 * @property {String} valueField Key for the value
 * @property {String} queryParam Name of the param passed to endpoint (query by default)
 * @property {String} server Endpoint for data provider
 * @property {String|Object} serverParams Parameters to pass along to the server
 * @property {Boolean} liveServer Should the endpoint be called each time on input
 * @property {Boolean} noCache Prevent caching by appending a timestamp
 * @property {Number} debounceTime Debounce time for live server
 * @property {String} notFoundMessage Display a no suggestions found message. Leave empty to disable
 * @property {Function} onRenderItem Callback function that returns the label
 * @property {Function} onSelectItem Callback function to call on selection
 * @property {Function} onClearItem Callback function to call on clear
 * @property {Function} onServerResponse Callback function to process server response. Must return a Promise
 */
/**
 * @type {Config}
 */
const e={allowNew:false,showAllSuggestions:false,badgeStyle:"primary",allowClear:false,clearEnd:false,selected:[],regex:"",separator:[],max:0,clearLabel:"Clear",searchLabel:"Type a value",keepOpen:false,allowSame:false,baseClass:"",placeholder:"",addOnBlur:false,suggestionsThreshold:1,maximumItems:0,autoselectFirst:true,updateOnSelect:false,fullWidth:false,fixed:false,labelField:"label",valueField:"value",queryParam:"query",server:"",serverParams:{},liveServer:false,noCache:true,debounceTime:300,notFoundMessage:"",onRenderItem:(e,t)=>t,onSelectItem:e=>{},onClearItem:e=>{},onServerResponse:e=>e.json()};const t="tags-";const s="is-loading";const i="is-active";const n=["is-active","bg-primary","text-white"];const l="data-value";const r="next";const o="prev";const a="form-control-focus";const h=new WeakMap;let c=0;
/**
 * @param {Function} func
 * @param {number} timeout
 * @returns {Function}
 */function debounce(e,t=300){let s;return(...i)=>{clearTimeout(s);s=setTimeout((()=>{e.apply(this,i)}),t)}}
/**
 * @param {string} text
 * @param {string} size
 * @returns {Number}
 */function calcTextWidth(e,t=null){const s=document.createElement("span");document.body.appendChild(s);s.style.fontSize=t||"inherit";s.style.height="auto";s.style.width="auto";s.style.position="absolute";s.style.whiteSpace="no-wrap";s.innerHTML=e;const i=Math.ceil(s.clientWidth)+8;document.body.removeChild(s);return i}
/**
 * @param {String} str
 * @returns {String}
 */function removeDiacritics(e){return e.normalize("NFD").replace(/[\u0300-\u036f]/g,"")}
/**
 * @param {HTMLElement} el
 * @param {HTMLElement} newEl
 * @returns {HTMLElement}
 */function insertAfter(e,t){return e.parentNode.insertBefore(t,e.nextSibling)}class Tags{
/**
   * @param {HTMLSelectElement} el
   * @param {Object|Config} config
   */
constructor(e,t={}){if(e instanceof HTMLElement){h.set(e,this);c++;this._selectElement=e;this._configure(t);this._keyboardNavigation=false;this._searchFunc=debounce((()=>{this._loadFromServer(true)}),this._config.debounceTime);this._fireEvents=true;this._initialValues=[];this._configureParent();this._holderElement=document.createElement("div");this._containerElement=document.createElement("div");this._holderElement.appendChild(this._containerElement);insertAfter(this._selectElement,this._holderElement);this._configureSelectElement();this._configureHolderElement();this._configureContainerElement();this._configureSearchInput();this._configureDropElement();this.resetState();if(this._config.fixed){document.addEventListener("scroll",this);document.addEventListener("resize",this)}this._searchInput.addEventListener("focus",this);this._searchInput.addEventListener("blur",this);this._searchInput.addEventListener("input",this);this._searchInput.addEventListener("keydown",this);this._dropElement.addEventListener("mousemove",this);this._fetchData()}else console.error("Invalid element",e)}
/**
   * Attach to all elements matched by the selector
   * @param {string} selector
   * @param {Object} opts
   */
static init(e="select[multiple]",t={}){
/**
     * @type {NodeListOf<HTMLSelectElement>}
     */
let s=document.querySelectorAll(e);for(let e=0;e<s.length;e++)Tags.getInstance(s[e])||new Tags(s[e],t)}
/**
   * @param {HTMLSelectElement} el
   */static getInstance(e){if(h.has(e))return h.get(e)}dispose(){this._searchInput.removeEventListener("focus",this);this._searchInput.removeEventListener("blur",this);this._searchInput.removeEventListener("input",this);this._searchInput.removeEventListener("keydown",this);this._dropElement.removeEventListener("mousemove",this);if(this._config.fixed){document.removeEventListener("scroll",this);document.removeEventListener("resize",this)}this._selectElement.style.display="block";this._holderElement.parentElement.removeChild(this._holderElement);this.parentForm&&this.parentForm.removeEventListener("reset",this.reset);h.delete(this._selectElement)}
/**
   * @link https://gist.github.com/WebReflection/ec9f6687842aa385477c4afca625bbf4#handling-events
   * @param {Event} event
   */handleEvent(e){this[`on${e.type}`](e)}
/**
   * @param {Config|Object} config
   */_configure(t={}){this._config=Object.assign({},e);const s={...t,...this._selectElement.dataset};const parseBool=e=>["true","false","1","0",true,false].includes(e)&&!!JSON.parse(e);for(const[t,i]of Object.entries(e)){if(void 0===s[t])continue;const e=s[t];switch(typeof i){case"number":this._config[t]=parseInt(e);break;case"boolean":this._config[t]=parseBool(e);break;case"string":this._config[t]=e.toString();break;case"object":if(Array.isArray(i)){const s=e.includes("|")?"|":",";this._config[t]="string"===typeof e?e.split(s):e}else this._config[t]="string"===typeof e?JSON.parse(e):e;break;case"function":this._config[t]="string"===typeof e?window[e]:e;break;default:this._config[t]=e;break}}this._config.placeholder||(this._config.placeholder=this._getPlaceholder())}_configureParent(){this.overflowParent=null;this.parentForm=this._selectElement.parentElement;while(this.parentForm){"hidden"===this.parentForm.style.overflow&&(this.overflowParent=this.parentForm);this.parentForm=this.parentForm.parentElement;if(this.parentForm&&"FORM"==this.parentForm.nodeName)break}this.reset=this.reset.bind(this);this.parentForm&&this.parentForm.addEventListener("reset",this.reset)}
/**
   * @returns {string}
   */_getPlaceholder(){if(this._selectElement.hasAttribute("placeholder"))return this._selectElement.getAttribute("placeholder");if(this._selectElement.dataset.placeholder)return this._selectElement.dataset.placeholder;let e=this._selectElement.querySelector("option");if(!e)return"";e.hasAttribute("selected")&&e.removeAttribute("selected");return e.value?"":e.textContent}_configureSelectElement(){this._selectElement.style.position="absolute";this._selectElement.style.left="-9999px";this._selectElement.addEventListener("focus",(e=>{this._searchInput.focus()}))}_configureDropElement(){this._dropElement=document.createElement("ul");this._dropElement.classList.add("dropdown-menu",t+"menu","p-0");this._dropElement.setAttribute("id",t+"menu-"+c);this._dropElement.setAttribute("role","menu");this._dropElement.style.maxHeight="280px";this._config.fullWidth||(this._dropElement.style.maxWidth="360px");this._config.fixed&&(this._dropElement.style.position="fixed");this._dropElement.style.overflowY="auto";this._dropElement.addEventListener("mouseenter",(e=>{this._keyboardNavigation=false}));this._holderElement.appendChild(this._dropElement);this._searchInput.setAttribute("aria-controls",this._dropElement.getAttribute("id"))}_configureHolderElement(){this._holderElement.classList.add("form-control","dropdown");this._selectElement.classList.contains("form-select-lg")&&this._holderElement.classList.add("form-control-lg");this._selectElement.classList.contains("form-select-sm")&&this._holderElement.classList.add("form-control-sm");this.overflowParent&&(this._holderElement.style.position="inherit");4===this._getBootstrapVersion()&&(this._holderElement.style.height="auto")}_configureContainerElement(){this._containerElement.addEventListener("click",(e=>{this.isDisabled()||"hidden"!=this._searchInput.style.visibility&&this._searchInput.focus()}));this._containerElement.style.display="flex";this._containerElement.style.alignItems="center";this._containerElement.style.flexWrap="wrap";let e=this._selectElement.selectedOptions??[];for(let t=0;t<e.length;t++){let s=e[t];if(s.value){s.setAttribute("selected","selected");this._initialValues.push(s);this._createBadge(s.textContent,s.value)}}}_configureSearchInput(){this._searchInput=document.createElement("input");this._searchInput.type="text";this._searchInput.autocomplete="off";this._searchInput.spellcheck=false;this._searchInput.ariaAutoComplete="list";this._searchInput.ariaExpanded="false";this._searchInput.ariaHasPopup="menu";this._searchInput.setAttribute("role","combobox");this._searchInput.ariaLabel=this._config.searchLabel;this._searchInput.style.backgroundColor="transparent";this._searchInput.style.color="currentColor";this._searchInput.style.border="0";this._searchInput.style.outline="0";this._searchInput.style.maxWidth="100%";this.resetSearchInput(true);this._containerElement.appendChild(this._searchInput)}onfocus(e){this._holderElement.classList.add(a);this._showOrSearch()}onblur(e){this._abortController&&this._abortController.abort();this._holderElement.classList.remove(a);this._hideSuggestions();this._config.keepOpen&&this.resetSearchInput();const t=this.getSelection();const s={selection:t?t.dataset.value:null,input:this._searchInput.value};if(this._config.addOnBlur&&this._config.allowNew&&this.canAdd(s.input)){this.addItem(s.input);this.resetSearchInput()}this._fireEvents&&this._selectElement.dispatchEvent(new CustomEvent("tags.blur",{bubbles:true,detail:s}))}oninput(e){const t=this._searchInput.value;if(t){const e=t.slice(-1);if(this._config.separator.length&&this._config.separator.includes(e)){this._searchInput.value=this._searchInput.value.slice(0,-1);this._add(this._searchInput.value,null);return}}this._adjustWidth();this._showOrSearch()}
/**
   * keypress doesn't send arrow keys, so we use keydown
   * @param {KeyboardEvent} event
   */onkeydown(e){let t=e.keyCode||e.key;
/**
     * @type {HTMLInputElement}
     */const s=e.target;229==e.keyCode&&(t=s.value.charAt(s.selectionStart-1).charCodeAt(0));switch(t){case 13:case"Enter":e.preventDefault();let t=this.getSelection();if(t)t.click();else if(this._config.allowNew&&this._searchInput.value){let e=this._searchInput.value;this._add(e,null)}break;case 38:case"ArrowUp":e.preventDefault();this._keyboardNavigation=true;this._moveSelection(o);break;case 40:case"ArrowDown":e.preventDefault();this._keyboardNavigation=true;this._moveSelection(r);break;case 8:case"Backspace":if(0==this._searchInput.value.length){this.removeLastItem();this._adjustWidth();this._showOrSearch()}break;case 27:case"Escape":this._searchInput.focus();this._hideSuggestions();break}}onmousemove(e){this._keyboardNavigation=false}onscroll(e){this._positionMenu()}onresize(e){this._positionMenu()}resetState(){if(this.isDisabled()){this._holderElement.setAttribute("readonly","");this._searchInput.setAttribute("disabled","")}else{this._holderElement.hasAttribute("readonly")&&this._holderElement.removeAttribute("readonly");this._searchInput.hasAttribute("disabled")&&this._searchInput.removeAttribute("disabled")}}resetSuggestions(){let e=Array.from(this._selectElement.querySelectorAll("option")).filter((e=>!e.disabled)).map((e=>({value:e.getAttribute("value"),label:e.textContent})));this._buildSuggestions(e)}
/**
   * @param {boolean} show
   */_loadFromServer(e=false){this._abortController&&this._abortController.abort();this._abortController=new AbortController;const t=Object.assign({},this._config.serverParams);t[this._config.queryParam]=this._searchInput.value;this._config.noCache&&(t.t=Date.now());if(t.related){
/**
       * @type {HTMLInputElement}
       */
const e=document.getElementById(t.related);e&&(t.related=e.value)}const i=new URLSearchParams(t).toString();this._holderElement.classList.add(s);fetch(this._config.server+"?"+i,{signal:this._abortController.signal}).then((e=>this._config.onServerResponse(e))).then((t=>{let s=t.data||t;this._buildSuggestions(s);this._abortController=null;e&&this._showSuggestions()})).catch((e=>{"AbortError"!==e.name&&console.error(e)})).finally((e=>{this._holderElement.classList.remove(s)}))}
/**
   * @param {string} text
   * @param {string} value
   * @param {object} data
   */_add(e,t=null,s={}){if(this.canAdd(e,t)){this.addItem(e,t,s);this._config.keepOpen?this._showSuggestions():this.resetSearchInput()}}
/**
   * @param {String} dir
   * @returns {HTMLElement}
   */_moveSelection(e=r){const t=this.getSelection();
/**
     * @type {*|HTMLElement}
     */let s=null;if(t){const i=e===r?"nextSibling":"previousSibling";s=t.parentNode;do{s=s[i]}while(s&&"none"===s.style.display);if(s){t.classList.remove(...n);e===o?s.parentNode.scrollTop=s.offsetTop-s.parentNode.offsetTop:s.offsetTop>s.parentNode.offsetHeight-s.offsetHeight&&(s.parentNode.scrollTop+=s.offsetHeight)}else t&&(s=t.parentElement)}else{s=this._dropElement.firstChild;while(s&&"none"===s.style.display)s=s.nextSibling}if(s){const e=s.querySelector("a");e.classList.add(...n);this._searchInput.setAttribute("aria-activedescendant",e.getAttribute("id"));if(this._config.updateOnSelect){this._searchInput.value=e.dataset.label;this._adjustWidth()}}else this._searchInput.setAttribute("aria-activedescendant","");return s}_adjustWidth(){if(this._searchInput.value)this._searchInput.size=this._searchInput.value.length;else if(this.getSelectedValues().length){this._searchInput.placeholder="";this._searchInput.size=1}else{this._searchInput.size=this._config.placeholder.length>0?this._config.placeholder.length:1;this._searchInput.placeholder=this._config.placeholder}const e=this._searchInput.value||this._searchInput.placeholder;const t=window.getComputedStyle(this._holderElement).fontSize;const s=calcTextWidth(e,t);this._searchInput.style.minWidth=s+"px"}
/**
   * Add suggestions to the drop element
   * @param {array} suggestions
   */_buildSuggestions(e){while(this._dropElement.lastChild)this._dropElement.removeChild(this._dropElement.lastChild);for(let t=0;t<e.length;t++){const s=e[t];if(!s[this._config.valueField])continue;const i=s[this._config.valueField];const r=s[this._config.labelField];if(!this._config.liveServer&&(s.selected||this._config.selected.includes(i))){this._initialValues.push({value:i,textContent:r,dataset:s.data});this._add(r,i,s.data);continue}const o=this._config.onRenderItem(s,r);const a=document.createElement("li");a.setAttribute("role","presentation");const h=document.createElement("a");a.append(h);h.setAttribute("id",this._dropElement.getAttribute("id")+"-"+t);h.classList.add("dropdown-item","text-truncate");h.setAttribute(l,i);h.setAttribute("data-label",r);h.setAttribute("href","#");h.textContent=o;this._dropElement.appendChild(a);h.addEventListener("mouseenter",(e=>{if(!this._keyboardNavigation){this.removeSelection();a.querySelector("a").classList.add(...n)}}));h.addEventListener("mousedown",(e=>{e.preventDefault()}));h.addEventListener("click",(e=>{e.preventDefault();this._add(o,i,s.data);this._config.onSelectItem(s)}))}if(this._config.notFoundMessage){const e=document.createElement("li");e.setAttribute("role","presentation");e.classList.add(t+"not-found");e.innerHTML=`<span class="dropdown-item">${this._config.notFoundMessage}</span>`;this._dropElement.appendChild(e)}}reset(){this.removeAll();this._fireEvents=false;for(let e=0;e<this._initialValues.length;e++){const t=this._initialValues[e];this.addItem(t.textContent,t.value,t.dataset)}this._adjustWidth();this._fireEvents=true}
/**
   * @param {Boolean} init Pass true during init
   */resetSearchInput(e=false){this._searchInput.value="";this._adjustWidth();if(!e){this._hideSuggestions();this._searchInput===document.activeElement&&this._searchInput.dispatchEvent(new Event("input"))}this._config.max&&this.getSelectedValues().length>=this._config.max?this._searchInput.style.visibility="hidden":"hidden"==this._searchInput.style.visibility&&(this._searchInput.style.visibility="visible");this.isSingle()&&!e&&document.activeElement.blur()}
/**
   * @returns {array}
   */getSelectedValues(){
/**
     * @type {NodeListOf<HTMLOptionElement>}
     */
const e=this._selectElement.querySelectorAll("option[selected]");return Array.from(e).map((e=>e.value))}
/**
   * Do we have enough input to show suggestions ?
   * @returns {Boolean}
   */_shouldShow(){return!this.isDisabled()&&this._searchInput.value.length>=this._config.suggestionsThreshold}_showOrSearch(){this._shouldShow()?this._config.liveServer?this._searchFunc():this._showSuggestions():this._hideSuggestions()}_showSuggestions(){if("hidden"==this._searchInput.style.visibility)return;const e=removeDiacritics(this._searchInput.value).toLowerCase();const s=this.getSelectedValues();const i=this._dropElement.querySelectorAll("li");let o=0;let a=null;let h=false;for(let t=0;t<i.length;t++){let r=i[t];let c=r.querySelector("a");if(!c){r.style.display="none";continue}c.classList.remove(...n);if(!this._config.allowSame&&-1!=s.indexOf(c.getAttribute(l))){r.style.display="none";continue}h=true;const d=removeDiacritics(r.textContent).toLowerCase();const u=!(e.length>0)||d.indexOf(e)>=0;if(this._config.showAllSuggestions||u){o++;r.style.display="list-item";!a&&u&&(a=r);this._config.maximumItems>0&&o>this._config.maximumItems&&(r.style.display="none")}else r.style.display="none"}if(a||this._config.showAllSuggestions){this._holderElement.classList.remove("is-invalid");a&&this._config.autoselectFirst&&this._moveSelection(r)}else this._config.allowNew||0===e.length&&!h?this._config.regex&&this.isInvalid()&&this._holderElement.classList.remove("is-invalid"):this._holderElement.classList.add("is-invalid");if(0===o||this.isInvalid())if(this._config.notFoundMessage){
/**
         * @type {HTMLElement}
         */
const e=this._dropElement.querySelector("."+t+"not-found");e.style.display="block"}else this._hideSuggestions();else{this._dropElement.classList.add("show");this._searchInput.ariaExpanded="true";this._positionMenu()}}
/**
   * Checks if parent is fixed for boundary checks
   * @returns {Boolean}
   */_hasFixedPosition(){if(this._config.fixed)return true;let e=this._holderElement.parentElement;while(e&&e instanceof HTMLElement){if("fixed"===e.style.position)return true;e=e.parentElement}return false}_positionMenu(){const e=this._searchInput.getBoundingClientRect();const t=this._hasFixedPosition();if(this._config.fullWidth){this._dropElement.style.left="-1px";this._dropElement.style.width=this._holderElement.offsetWidth+"px"}else{let s=this._config.fixed?e.x:this._searchInput.offsetLeft;const i=t?window.innerWidth:document.body.offsetWidth;const n=i-1-(e.x+this._dropElement.offsetWidth);n<0&&(s+=n);this._dropElement.style.left=s+"px"}if(this._config.fixed)this._dropElement.style.transform="translateY(calc(-"+window.pageYOffset+"px))";else{const s=t?window.innerHeight:document.body.offsetHeight;const i=e.y+window.pageYOffset+this._dropElement.offsetHeight;const n=s-i;n<0&&s>e.height?this._dropElement.style.transform="translateY(calc(-100% - "+this._searchInput.offsetHeight+"px))":this._dropElement.style.transform="none"}}_hideSuggestions(){this._dropElement.classList.remove("show");this._holderElement.classList.remove("is-invalid");this._searchInput.ariaExpanded="false";this.removeSelection()}
/**
   * @returns {Number}
   */_getBootstrapVersion(){let e=5;window.jQuery&&void 0!=$.fn.tooltip&&void 0!=$.fn.tooltip.Constructor&&(e=parseInt($.fn.tooltip.Constructor.VERSION.charAt(0)));return e}
/**
   * Find if label is already selected (based on attribute)
   * @param {string} text
   * @returns {boolean}
   */_isSelected(e){const t=Array.from(this._selectElement.querySelectorAll("option")).find((t=>t.textContent==e));return!(!t||!t.getAttribute("selected"))}_fetchData(){this._config.server&&!this._config.liveServer?this._loadFromServer():this.resetSuggestions()}
/**
   * Checks if value matches a configured regex
   * @param {string} value
   * @returns {boolean}
   */_validateRegex(e){const t=new RegExp(this._config.regex.trim());return t.test(e)}
/**
   * @returns {HTMLElement}
   */getSelection(){return this._dropElement.querySelector("a."+i)}removeSelection(){const e=this.getSelection();e&&e.classList.remove(...n)}
/**
   * @deprecated since 1.5
   * @returns {HTMLElement}
   */getActiveSelection(){return this.getSelection()}
/**
   * @deprecated since 1.5
   */removeActiveSelection(){return this.removeSelection()}removeAll(){let e=this.getSelectedValues();e.forEach((e=>{this.removeItem(e,true)}));this._adjustWidth()}
/**
   * @param {boolean} noEvents
   */removeLastItem(e=false){let t=this._containerElement.querySelectorAll("span");if(!t.length)return;let s=t[t.length-1];this.removeItem(s.getAttribute(l),e);e||this._config.onClearItem(s.getAttribute(l))}
/**
   * @returns {boolean}
   */isDisabled(){return this._selectElement.hasAttribute("disabled")||this._selectElement.disabled||this._selectElement.hasAttribute("readonly")}
/**
   * @returns {boolean}
   */isDropdownVisible(){return this._dropElement.classList.contains("show")}
/**
   * @returns {boolean}
   */isInvalid(){return this._holderElement.classList.contains("is-invalid")}
/**
   * @returns {boolean}
   */isSingle(){return!this._selectElement.hasAttribute("multiple")}
/**
   * @param {string} text
   * @param {string} value
   * @returns {boolean}
   */canAdd(e,t=null){t||(t=e);if(!e)return false;if(this.isDisabled())return false;if(!this.isSingle()&&!this._config.allowSame&&this._isSelected(e))return false;if(this._config.max&&this.getSelectedValues().length>=this._config.max)return false;if(this._config.regex&&!this._validateRegex(e)){this._holderElement.classList.add("is-invalid");return false}return true}
/**
   * You might want to use canAdd before to ensure the item is valid
   * @param {string} text
   * @param {string} value
   * @param {object} data
   */addItem(e,t=null,s={}){t||(t=e);this.isSingle()&&this.getSelectedValues().length&&this.removeLastItem(true);let i=this._selectElement.querySelectorAll('option[value="'+t+'"]');
/**
     * @type {HTMLOptionElement}
     */let n=null;this._config.allowSame?i.forEach((
/**
         * @param {HTMLOptionElement} o
         */
t=>{t.textContent!==e||t.selected||(n=t)})):n=i[0]??null;if(!n){n=document.createElement("option");n.value=t;n.textContent=e;for(const[e,t]of Object.entries(s))n.dataset[e]=t;this._selectElement.appendChild(n)}n&&(s=Object.assign({},s,n.dataset));n.setAttribute("selected","selected");n.selected=true;this._createBadge(e,t,s);this._fireEvents&&this._selectElement.dispatchEvent(new Event("change",{bubbles:true}))}
/**
   * @param {string} text
   * @param {string} value
   * @param {object} data
   */_createBadge(e,t=null,s={}){const i=this._getBootstrapVersion();let n=e;let r=document.createElement("span");let o=["badge"];let a=this._config.badgeStyle;s.badgeStyle&&(a=s.badgeStyle);s.badgeClass&&o.push(...s.badgeClass.split(" "));if(this._config.baseClass){5===i?o.push("me-2"):o.push("mr-2");o.push(...this._config.baseClass.split(" "))}else o=5===i?[...o,"me-2","my-1","bg-"+a,"mw-100","overflow-x-hidden"]:[...o,"mr-2","my-1","badge-"+a];r.classList.add(...o);r.setAttribute(l,t);if(this._config.allowClear){const e=o.includes("text-dark")?"btn-close":"btn-close-white";let t;let s;if(this._config.clearEnd){t=5===i?"ms-2":"ml-2";s=5===i?"float-end":"float:right;"}else{t=5===i?"me-2":"mr-2";s=5===i?"float-start":"float:left;"}const l=5===i?'<button type="button" style="font-size:0.65em" class="'+t+" "+s+" btn-close "+e+'" aria-label="'+this._config.clearLabel+'"></button>':'<button type="button" style="font-size:1em;'+s+'text-shadow:none;color:currentColor;transform:scale(1.2)" class="'+t+' close" aria-label="'+this._config.clearLabel+'"><span aria-hidden="true">&times;</span></button>';n=l+n}r.innerHTML=n;this._containerElement.insertBefore(r,this._searchInput);this._config.allowClear&&r.querySelector("button").addEventListener("click",(e=>{e.preventDefault();e.stopPropagation();if(!this.isDisabled()){this.removeItem(t);this._config.onClearItem(t);document.activeElement.blur();this._adjustWidth()}}))}
/**
   * @param {string} value
   * @param {boolean} value
   */removeItem(e,t=false){let s=this._containerElement.querySelector("span["+l+'="'+e+'"]');if(!s)return;s.remove();
/**
     * @type {HTMLOptionElement}
     */let i=this._selectElement.querySelector('option[value="'+e+'"][selected]');if(i){i.removeAttribute("selected");i.selected=false;this._fireEvents&&!t&&this._selectElement.dispatchEvent(new Event("change",{bubbles:true}))}"hidden"==this._searchInput.style.visibility&&this._config.max&&this.getSelectedValues().length<this._config.max&&(this._searchInput.style.visibility="visible")}}export{Tags as default};

