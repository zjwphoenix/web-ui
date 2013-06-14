// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library web_ui.custom_element;

import 'dart:async';
import 'dart:html';
import 'package:meta/meta.dart';
import 'src/custom_tag_name.dart';

/** Deprecated: use [CustomElement] instead. */
@deprecated
abstract class WebComponent extends CustomElement {}

// TODO(jmesserly): replace with a real custom element polyfill.
// This is just something temporary.
/**
 * *Warning*: this implementation is a work in progress. It only implements
 * the specification partially.
 *
 * Registers a custom HTML element with [localName] and the associated
 * constructor. This will ensure the element is detected and
 *
 * See the specification at:
 * <https://dvcs.w3.org/hg/webcomponents/raw-file/tip/spec/custom/index.html>
 */
void registerCustomElement(String localName, CustomElement create()) {
  if (_customElements == null) {
    _customElements = {};
    CustomElement.templateCreated.add(_createElements);
    // TODO(jmesserly): use MutationObserver to watch for inserts?
  }

  if (!isCustomTag(localName)) {
    throw new ArgumentError('$localName is not a valid custom element name, '
        'it should have at least one dash and not be a reserved name.');
  }

  if (_customElements.containsKey(localName)) {
    throw new ArgumentError('custom element $localName already registered.');
  }

  // TODO(jmesserly): validate this is a valid tag name, not a selector.
  _customElements[localName] = create;

  // Initialize elements already on the page.
  for (var query in [localName, '[is=$localName]']) {
    for (var element in document.queryAll(query)) {
      _initCustomElement(element, create);
    }
  }
}

/**
 * The base class for all Dart web components. In addition to the [Element]
 * interface, it also provides lifecycle methods:
 * - [created]
 * - [inserted]
 * - [attributeChanged]
 * - [removed]
 */
abstract class CustomElement implements Element {
  /** The web component element wrapped by this class. */
  Element _host;
  List _shadowRoots;

  /**
   * Shadow roots generated by dwc for each custom element, indexed by the
   * custom element tag name.
   */
  Map<String, dynamic> _generatedRoots = {};

  /**
   * Temporary property until components extend [Element]. An element can
   * only be associated with one host, and it is an error to use a web component
   * without an associated host element.
   */
  Element get host {
    if (_host == null) throw new StateError('host element has not been set.');
    return _host;
  }

  set host(Element value) {
    if (value == null) {
      throw new ArgumentError('host must not be null.');
    }
    // TODO(jmesserly): xtag used to return "null" if unset, now it checks for
    // "this". Temporarily allow both.
    var xtag = value.xtag;
    if (xtag != null && xtag != value) {
      throw new ArgumentError('host must not have its xtag property set.');
    }
    if (_host != null) {
      throw new StateError('host can only be set once.');
    }

    value.xtag = this;
    _host = value;
  }

  /**
   * **Note**: This is an implementation helper and should not need to be called
   * from your code.
   *
   * Creates the [ShadowRoot] backing this component.
   */
  createShadowRoot([String componentName]) {
    var root = host.createShadowRoot();
    if (componentName != null) {
      _generatedRoots[componentName] = root;
    }
    return root;
  }

  getShadowRoot(String componentName) => _generatedRoots[componentName];

  /** Any CSS selector (class, id or element) defined name to mangled name. */
  ScopedCssMapper _mapper = new ScopedCssMapper({});

  // TODO(terry): Add a mapper per component in the type hierarchy.
  ScopedCssMapper getScopedCss(String componentName) => _mapper;
  void setScopedCss(String componentName, ScopedCssMapper mapper) {
    _mapper = mapper;
  }

  /**
   * *Warning*: This is an implementation helper for Custom Elements and
   * should not be used in your code.
   *
   * Clones the template, instantiates custom elements and hooks events, then
   * returns it.
   */
  DocumentFragment cloneTemplate(DocumentFragment shadowTemplate) {
    var result = shadowTemplate.clone(true);
    if (_templateCreated != null) {
      for (var callback in _templateCreated) callback(result);
    }
    return result;
  }

  // TODO(jmesserly): ideally this would be a stream, but they don't allow
  // reentrancy.
  static Set<DocumentFragmentCreated> _templateCreated;

  /**
   * *Warning*: This is an implementation helper for Custom Elements and
   * should not be used in your code.
   *
   * This event is fired whenever a template is instantiated via
   * [cloneTemplate] or via [Element.createInstance]
   */
  // TODO(jmesserly): This is a hack, and is neccesary for the polyfill
  // because custom elements are not upgraded during clone()
  static Set<DocumentFragmentCreated> get templateCreated {
    if (_templateCreated == null) {
      _templateCreated = new Set<DocumentFragmentCreated>();
      TemplateElement.instanceCreated.listen((value) {
        for (var callback in _templateCreated) callback(value);
      });
    }
    return _templateCreated;
  }
  /**
   * Invoked when this component gets created.
   * Note that [root] will be a [ShadowRoot] if the browser supports Shadow DOM.
   */
  void created() {}

  /** Invoked when this component gets inserted in the DOM tree. */
  void inserted() {}

  /** Invoked when this component is removed from the DOM tree. */
  void removed() {}

  // TODO(jmesserly): how do we implement this efficiently?
  // See https://github.com/dart-lang/web-ui/issues/37
  /** Invoked when any attribute of the component is modified. */
  void attributeChanged(String name, String oldValue, String newValue) {}

  /**
   * **Note**: This is an implementation helper and should not need to be calle
   * from your code.
   *
   * Initializes the contents of the ShadowRoot from template inside the
   * `<element>` element.
   */
  void initShadow() {}

  get model => host.model;

  void set model(newModel) {
    host.model = newModel;
  }

  get templateInstance => host.templateInstance;
  get isTemplate => host.isTemplate;
  get ref => host.ref;
  get content => host.content;
  DocumentFragment createInstance() => host.createInstance();
  void bind(String name, model, String path) => host.bind(name, model, path);
  void unbind(String name) => host.unbind(name);
  void unbindAll() => host.unbindAll();

  // TODO(jmesserly): this forwarding is temporary until Dart supports
  // subclassing Elements.
  // TODO(jmesserly): we were missing the setter for title, are other things
  // missing setters?

  List<Node> get nodes => host.nodes;

  set nodes(Iterable<Node> value) { host.nodes = value; }

  /**
   * Replaces this node with another node.
   */
  Node replaceWith(Node otherNode) { host.replaceWith(otherNode); }

  /**
   * Removes this node from the DOM.
   */
  void remove() => host.remove();

  Node get nextNode => host.nextNode;

  Document get document => host.document;

  Node get previousNode => host.previousNode;

  String get text => host.text;

  set text(String v) { host.text = v; }

  bool contains(Node other) => host.contains(other);

  bool hasChildNodes() => host.hasChildNodes();

  Node insertBefore(Node newChild, Node refChild) =>
    host.insertBefore(newChild, refChild);

  Node insertAllBefore(Iterable<Node> newChild, Node refChild) =>
    host.insertAllBefore(newChild, refChild);

  Map<String, String> get attributes => host.attributes;
  set attributes(Map<String, String> value) {
    host.attributes = value;
  }

  List<Element> get elements => host.children;

  set elements(List<Element> value) {
    host.children = value;
  }

  List<Element> get children => host.children;

  set children(List<Element> value) {
    host.children = value;
  }

  Set<String> get classes => host.classes;

  set classes(Iterable<String> value) {
    host.classes = value;
  }

  Map<String, String> getNamespacedAttributes(String namespace) =>
      host.getNamespacedAttributes(namespace);

  CssStyleDeclaration getComputedStyle([String pseudoElement])
    => host.getComputedStyle(pseudoElement);

  Element clone(bool deep) => host.clone(deep);

  Element get parent => host.parent;

  Node get parentNode => host.parentNode;

  String get nodeValue => host.nodeValue;

  @deprecated
  // TODO(sigmund): restore the old return type and call host.on when
  // dartbug.com/8131 is fixed.
  dynamic get on { throw new UnsupportedError('on is deprecated'); }

  String get contentEditable => host.contentEditable;
  set contentEditable(String v) { host.contentEditable = v; }

  String get dir => host.dir;
  set dir(String v) { host.dir = v; }

  bool get draggable => host.draggable;
  set draggable(bool v) { host.draggable = v; }

  bool get hidden => host.hidden;
  set hidden(bool v) { host.hidden = v; }

  String get id => host.id;
  set id(String v) { host.id = v; }

  String get innerHTML => host.innerHtml;

  void set innerHTML(String v) {
    host.innerHtml = v;
  }

  String get innerHtml => host.innerHtml;
  void set innerHtml(String v) {
    host.innerHtml = v;
  }

  bool get isContentEditable => host.isContentEditable;

  String get lang => host.lang;
  set lang(String v) { host.lang = v; }

  String get outerHtml => host.outerHtml;

  bool get spellcheck => host.spellcheck;
  set spellcheck(bool v) { host.spellcheck = v; }

  int get tabIndex => host.tabIndex;
  set tabIndex(int i) { host.tabIndex = i; }

  String get title => host.title;

  set title(String value) { host.title = value; }

  bool get translate => host.translate;
  set translate(bool v) { host.translate = v; }

  String get dropzone => host.dropzone;
  set dropzone(String v) { host.dropzone = v; }

  void click() { host.click(); }

  InputMethodContext getInputContext() => host.getInputContext();

  Element insertAdjacentElement(String where, Element element) =>
    host.insertAdjacentElement(where, element);

  void insertAdjacentHtml(String where, String html) {
    host.insertAdjacentHtml(where, html);
  }

  void insertAdjacentText(String where, String text) {
    host.insertAdjacentText(where, text);
  }

  Map<String, String> get dataset => host.dataset;

  set dataset(Map<String, String> value) {
    host.dataset = value;
  }

  Element get nextElementSibling => host.nextElementSibling;

  Element get offsetParent => host.offsetParent;

  Element get previousElementSibling => host.previousElementSibling;

  CssStyleDeclaration get style => host.style;

  String get tagName => host.tagName;

  String get pseudo => host.pseudo;

  void set pseudo(String value) {
    host.pseudo = value;
  }

  // Note: we are not polyfilling the shadow root here. This will be fixed when
  // we migrate to the JS Shadow DOM polyfills. You can still use getShadowRoot
  // to retrieve a node that behaves as the shadow root when Shadow DOM is not
  // enabled.
  ShadowRoot get shadowRoot => host.shadowRoot;

  void blur() { host.blur(); }

  void focus() { host.focus(); }

  void scrollByLines(int lines) {
    host.scrollByLines(lines);
  }

  void scrollByPages(int pages) {
    host.scrollByPages(pages);
  }

  void scrollIntoView([ScrollAlignment alignment]) {
    host.scrollIntoView(alignment);
  }

  bool matches(String selectors) => host.matches(selectors);

  @deprecated
  void requestFullScreen(int flags) { requestFullscreen(); }

  void requestFullscreen() { host.requestFullscreen(); }

  void requestPointerLock() { host.requestPointerLock(); }

  Element query(String selectors) => host.query(selectors);

  ElementList queryAll(String selectors) => host.queryAll(selectors);

  HtmlCollection get $dom_children => host.$dom_children;

  int get $dom_childElementCount => host.$dom_childElementCount;

  String get $dom_className => host.$dom_className;
  set $dom_className(String value) { host.$dom_className = value; }

  @deprecated
  int get clientHeight => client.height;

  @deprecated
  int get clientLeft => client.left;

  @deprecated
  int get clientTop => client.top;

  @deprecated
  int get clientWidth => client.width;

  Rect get client => host.client;

  Element get $dom_firstElementChild => host.$dom_firstElementChild;

  Element get $dom_lastElementChild => host.$dom_lastElementChild;

  @deprecated
  int get offsetHeight => offset.height;

  @deprecated
  int get offsetLeft => offset.left;

  @deprecated
  int get offsetTop => offset.top;

  @deprecated
  int get offsetWidth => offset.width;

  Rect get offset => host.offset;

  int get scrollHeight => host.scrollHeight;

  int get scrollLeft => host.scrollLeft;

  int get scrollTop => host.scrollTop;

  set scrollLeft(int value) { host.scrollLeft = value; }

  set scrollTop(int value) { host.scrollTop = value; }

  int get scrollWidth => host.scrollWidth;

  String $dom_getAttribute(String name) =>
      host.$dom_getAttribute(name);

  String $dom_getAttributeNS(String namespaceUri, String localName) =>
      host.$dom_getAttributeNS(namespaceUri, localName);

  String $dom_setAttributeNS(
      String namespaceUri, String localName, String value) {
    host.$dom_setAttributeNS(namespaceUri, localName, value);
  }

  bool $dom_hasAttributeNS(String namespaceUri, String localName) =>
      host.$dom_hasAttributeNS(namespaceUri, localName);

  void $dom_removeAttributeNS(String namespaceUri, String localName) =>
      host.$dom_removeAttributeNS(namespaceUri, localName);

  Rect getBoundingClientRect() => host.getBoundingClientRect();

  List<Rect> getClientRects() => host.getClientRects();

  List<Node> getElementsByClassName(String name) =>
      host.getElementsByClassName(name);

  List<Node> $dom_getElementsByTagName(String name) =>
      host.$dom_getElementsByTagName(name);

  bool $dom_hasAttribute(String name) =>
      host.$dom_hasAttribute(name);

  List<Node> $dom_querySelectorAll(String selectors) =>
      host.$dom_querySelectorAll(selectors);

  void $dom_removeAttribute(String name) =>
      host.$dom_removeAttribute(name);

  void $dom_setAttribute(String name, String value) =>
      host.$dom_setAttribute(name, value);

  get $dom_attributes => host.$dom_attributes;

  List<Node> get $dom_childNodes => host.$dom_childNodes;

  Node get $dom_firstChild => host.$dom_firstChild;

  Node get $dom_lastChild => host.$dom_lastChild;

  String get localName => host.localName;
  String get $dom_localName => host.$dom_localName;

  String get namespaceUri => host.namespaceUri;
  String get $dom_namespaceUri => host.$dom_namespaceUri;

  int get nodeType => host.nodeType;

  void $dom_addEventListener(String type, EventListener listener,
                             [bool useCapture]) {
    host.$dom_addEventListener(type, listener, useCapture);
  }

  bool dispatchEvent(Event event) => host.dispatchEvent(event);

  Node $dom_removeChild(Node oldChild) => host.$dom_removeChild(oldChild);

  void $dom_removeEventListener(String type, EventListener listener,
                                [bool useCapture]) {
    host.$dom_removeEventListener(type, listener, useCapture);
  }

  Node $dom_replaceChild(Node newChild, Node oldChild) =>
      host.$dom_replaceChild(newChild, oldChild);

  get xtag => host.xtag;

  set xtag(value) { host.xtag = value; }

  Node append(Node e) => host.append(e);

  void appendText(String text) => host.appendText(text);

  void appendHtml(String html) => host.appendHtml(html);

  void $dom_scrollIntoView([bool alignWithTop]) {
    if (alignWithTop == null) {
      host.$dom_scrollIntoView();
    } else {
      host.$dom_scrollIntoView(alignWithTop);
    }
  }

  void $dom_scrollIntoViewIfNeeded([bool centerIfNeeded]) {
    if (centerIfNeeded == null) {
      host.$dom_scrollIntoViewIfNeeded();
    } else {
      host.$dom_scrollIntoViewIfNeeded(centerIfNeeded);
    }
  }

  String get regionOverset => host.regionOverset;

  List<Range> getRegionFlowRanges() => host.getRegionFlowRanges();

  // TODO(jmesserly): rename "created" to "onCreated".
  void onCreated() => created();

  Stream<Event> get onAbort => host.onAbort;
  Stream<Event> get onBeforeCopy => host.onBeforeCopy;
  Stream<Event> get onBeforeCut => host.onBeforeCut;
  Stream<Event> get onBeforePaste => host.onBeforePaste;
  Stream<Event> get onBlur => host.onBlur;
  Stream<Event> get onChange => host.onChange;
  Stream<MouseEvent> get onClick => host.onClick;
  Stream<MouseEvent> get onContextMenu => host.onContextMenu;
  Stream<Event> get onCopy => host.onCopy;
  Stream<Event> get onCut => host.onCut;
  Stream<Event> get onDoubleClick => host.onDoubleClick;
  Stream<MouseEvent> get onDrag => host.onDrag;
  Stream<MouseEvent> get onDragEnd => host.onDragEnd;
  Stream<MouseEvent> get onDragEnter => host.onDragEnter;
  Stream<MouseEvent> get onDragLeave => host.onDragLeave;
  Stream<MouseEvent> get onDragOver => host.onDragOver;
  Stream<MouseEvent> get onDragStart => host.onDragStart;
  Stream<MouseEvent> get onDrop => host.onDrop;
  Stream<Event> get onError => host.onError;
  Stream<Event> get onFocus => host.onFocus;
  Stream<Event> get onInput => host.onInput;
  Stream<Event> get onInvalid => host.onInvalid;
  Stream<KeyboardEvent> get onKeyDown => host.onKeyDown;
  Stream<KeyboardEvent> get onKeyPress => host.onKeyPress;
  Stream<KeyboardEvent> get onKeyUp => host.onKeyUp;
  Stream<Event> get onLoad => host.onLoad;
  Stream<MouseEvent> get onMouseDown => host.onMouseDown;
  Stream<MouseEvent> get onMouseMove => host.onMouseMove;
  Stream<Event> get onFullscreenChange => host.onFullscreenChange;
  Stream<Event> get onFullscreenError => host.onFullscreenError;
  Stream<Event> get onPaste => host.onPaste;
  Stream<Event> get onReset => host.onReset;
  Stream<Event> get onScroll => host.onScroll;
  Stream<Event> get onSearch => host.onSearch;
  Stream<Event> get onSelect => host.onSelect;
  Stream<Event> get onSelectStart => host.onSelectStart;
  Stream<Event> get onSubmit => host.onSubmit;
  Stream<MouseEvent> get onMouseOut => host.onMouseOut;
  Stream<MouseEvent> get onMouseOver => host.onMouseOver;
  Stream<MouseEvent> get onMouseUp => host.onMouseUp;
  Stream<TouchEvent> get onTouchCancel => host.onTouchCancel;
  Stream<TouchEvent> get onTouchEnd => host.onTouchEnd;
  Stream<TouchEvent> get onTouchEnter => host.onTouchEnter;
  Stream<TouchEvent> get onTouchLeave => host.onTouchLeave;
  Stream<TouchEvent> get onTouchMove => host.onTouchMove;
  Stream<TouchEvent> get onTouchStart => host.onTouchStart;
  Stream<TransitionEvent> get onTransitionEnd => host.onTransitionEnd;

  // TODO(sigmund): do the normal forwarding when dartbug.com/7919 is fixed.
  Stream<WheelEvent> get onMouseWheel {
    throw new UnsupportedError('onMouseWheel is not supported');
  }
}

/**
 * Maps CSS selectors (class and) to a mangled name and maps x-component name
 * to [is='x-component'].
 */
class ScopedCssMapper {
  final Map<String, String> _mapping;

  ScopedCssMapper(this._mapping);

  /** Returns mangled name of selector sans . or # character. */
  String operator [](String selector) => _mapping[selector];

  /** Returns mangled name of selector w/ . or # character. */
  String getSelector(String selector) {
    var prefixedName = this[selector];
    var selectorType = selector[0];
    if (selectorType == '.' || selectorType == '#') {
      return '$selectorType${prefixedName}';
    }

    return prefixedName;
  }
}

typedef DocumentFragmentCreated(DocumentFragment fragment);

Map<String, Function> _customElements;

void _createElements(Node node) {
  for (var c = node.$dom_firstChild; c != null; c = c.nextNode) {
    _createElements(c);
  }
  if (node is Element) {
    var ctor = _customElements[node.localName];
    if (ctor == null) {
      var isAttr = node.attributes['is'];
      if (isAttr != null) ctor = _customElements[isAttr];
    }
    if (ctor != null) _initCustomElement(node, ctor);
  }
}

void _initCustomElement(Element node, CustomElement ctor()) {
  CustomElement element = ctor();
  element.host = node;

  // TODO(jmesserly): replace lifecycle stuff with a proper polyfill.
  element..initShadow()..created();

  _registerLifecycleInsert(element);
}

void _registerLifecycleInsert(CustomElement element) {
  runAsync(() {
    // TODO(jmesserly): bottom up or top down insert?
    var node = element.host;

    // TODO(jmesserly): need a better check to see if the node has been removed.
    if (node.parentNode == null) return;

    _registerLifecycleRemove(element);
    element.inserted();
  });
}

void _registerLifecycleRemove(CustomElement element) {
  // TODO(jmesserly): need fallback or polyfill for MutationObserver.
  if (!MutationObserver.supported) return;

  new MutationObserver((records, observer) {
    var node = element.host;
    for (var record in records) {
      for (var removed in record.removedNodes) {
        if (identical(node, removed)) {
          observer.disconnect();
          element.removed();
          return;
        }
      }
    }
  }).observe(element.parentNode, childList: true);
}

/**
 * DEPRECATED: this has no effect. Shadow DOM should always be used with custom
 * elements.
 *
 * Set this to true to use native Shadow DOM if it is supported.
 * Note that this will change behavior of [WebComponent] APIs for tree
 * traversal.
 */
@deprecated
bool useShadowDom = false;