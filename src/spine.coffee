# # Events
# クラスじゃなくてオブジェクト
Events =
  bind: (ev, callback) ->
    # 空白で分割してイベントの配列にする
    evs   = ev.split(' ')
    # \_callbacksっていう属性を持っていなければ {}
    calls = @hasOwnProperty('_callbacks') and @_callbacks or= {}

    # calls配列にpush
    for name in evs
      calls[name] or= []
      calls[name].push(callback)
    this

  # 一回のみ実行されるように
  one: (ev, callback) ->
    # unbindしてcallbackを実行する関数を渡す
    @bind ev, ->
      @unbind(ev, arguments.callee)
      callback.apply(@, arguments)

  # イベント発生
  trigger: (args...) ->
    ev = args.shift()
    # コールバック関数のリストを取得
    list = @hasOwnProperty('_callbacks') and @_callbacks?[ev]
    return unless list
    # リストに入ったコールバックを次々に実行していく
    for callback in list
      if callback.apply(@, args) is false
        break
    true

  # unbindする
  unbind: (ev, callback) ->
    # ev がなければまっさらにする
    unless ev
      @_callbacks = {}
      return this
    # 対応するイベントのリストを取得
    list = @_callbacks?[ev]
    return this unless list

    # callbackがなければリストを削除
    unless callback
      delete @_callbacks[ev]
      return this

    # リストからコールバックと同じ物を探して削除
    for cb, i in list when cb is callback
      list = list.slice()
      list.splice(i, 1)
      @_callbacks[ev] = list
      break
    this

# # Log
Log =
  trace: true

  logPrefix: '(App)'

  log: (args...) ->
    # traceがfalseだったらやめ
    return unless @trace
    # プレフィクスがあればくっつけてコンソールに出力
    if @logPrefix then args.unshift(@logPrefix)
    console?.log?(args...)
    this

moduleKeywords = ['included', 'extended']

# # Module
# 最上位
# include, extend, proxy, constructorを定義している
class Module
  #引数で与えられたオブジェクトのプロパティをprototypeに取り込む
  @include: (obj) ->
    throw('include(obj) requires obj') unless obj
    for key, value of obj when key not in moduleKeywords
      # ::はprototypeへのアクセス
      # @:: = this.prototype
      @::[key] = value
    # コールバック
    obj.included?.apply(@)
    this

  #引数で与えられたオブジェクトのプロパティを拡張する
  @extend: (obj) ->
    throw('extend(obj) requires obj') unless obj
    for key, value of obj when key not in moduleKeywords
      @[key] = value
    # コールバック
    obj.extended?.apply(@)
    this
  # @proxyとproxxyの2つがある理由がわからん
  @proxy: (func) ->
    => func.apply(@, arguments)

  proxy: (func) ->
    => func.apply(@, arguments)

  # initが定義されていれば実行する
  constructor: ->
    @init?(arguments...)

# # Model
class Model extends Module
#     __extends = function(child, parent) {
#       for (var key in parent) {
#         if (__hasProp.call(parent, key)) child[key] = parent[key];
#     }
#     function ctor() { this.constructor = child; }
#     ctor.prototype = parent.prototype;
#     child.prototype = new ctor;
#     child.__super__ = parent.prototype; return child; },

  # Eventsを拡張
  @extend Events

  @records: {}
  # cidでレコードを管理する
  @crecords: {}
  @attributes: []

  @configure: (name, attributes...) ->
    @className  = name
    @records    = {}
    @crecords   = {}
    @attributes = attributes if attributes.length
    @attributes and= makeArray(@attributes)
    @attributes or=  []
    @unbind()
    this

  @toString: -> "#{@className}(#{@attributes.join(", ")})"

  @find: (id) ->
    record = @records[id]
    # レコードが見つからなくて、文字列がcidに一致していればcidで探す
    if !record and ("#{id}").match(/c-\d+/)
      return @findCID(id)
    throw('Unknown record') unless record
    record.clone()
　
  # cidで探す
  @findCID: (cid) ->
    record = @crecords[cid]
    throw('Unknown record') unless record
    record.clone()
  # 在るか？
  @exists: (id) ->
    try
      return @find(id)
    catch e
      return false

  # 再読み込みしたらrefreshトリガーを発生させる
  @refresh: (values, options = {}) ->
    if options.clear
      @records  = {}
      @crecords = {}

    records = @fromJSON(values)
    records = [records] unless isArray(records)

    for record in records
      record.id           or= record.cid
      @records[record.id]   = record
      @crecords[record.cid] = record

    @resetIdCounter()

    @trigger('refresh', not options.clear and @cloneArray(records))
    this

　# callbackで選択する
  @select: (callback) ->
    result = (record for id, record of @records when callback(record))
    @cloneArray(result)

  # 属性検索
  #
  # 一致した最初のレコードを返す
  @findByAttribute: (name, value) ->
    for id, record of @records
      if record[name] is value
        return record.clone()
    null

  # マッチするすべてのレコードを返す
  @findAllByAttribute: (name, value) ->
    @select (item) ->
      item[name] is value

  # 全てにコールバック関数を適用する
  @each: (callback) ->
    for key, value of @records
      callback(value.clone())
  # 全てを返す
  @all: ->
    @cloneArray(@recordsValues())
  # 最初のレコードを返す
  @first: ->
    record = @recordsValues()[0]
    record?.clone()
  # 最後のレコードを返す
  @last: ->
    values = @recordsValues()
    record = values[values.length - 1]
    record?.clone()
  # 数える
  @count: ->
    @recordsValues().length
  # 全部消す
  @deleteAll: ->
    for key, value of @records
      delete @records[key]
  # destroyは内部メソッド
  @destroyAll: ->
    for key, value of @records
      @records[key].destroy()

  @update: (id, atts, options) ->
    @find(id).updateAttributes(atts, options)

  @create: (atts, options) ->
    # これがよくわからん attsって実際なに？
    record = new @(atts)
    record.save(options)

  # destroyは内部メソッド
  @destroy: (id, options) ->
    @find(id).destroy(options)

  #関数だったらbind,パラメーターだったらトリガー
  @change: (callbackOrParams) ->
    if typeof callbackOrParams is 'function'
      @bind('change', callbackOrParams)
    else
      @trigger('change', callbackOrParams)

  #関数だったらbind,パラメーターだったらトリガー
  @fetch: (callbackOrParams) ->
    if typeof callbackOrParams is 'function'
      @bind('fetch', callbackOrParams)
    else
      @trigger('fetch', callbackOrParams)

  # 配列を返す
  @toJSON: ->
    @recordsValues()

  @fromJSON: (objects) ->
    return unless objects
    if typeof objects is 'string'
      objects = JSON.parse(objects)
    if isArray(objects)
      # 何をnewしているのか？
      (new @(value) for value in objects)
    else
      new @(objects)

  # ちょっとわからん
  @fromForm: ->
    (new this).fromForm(arguments...)

  # ### Private

  # valueを配列にして戻す
  @recordsValues: ->
    result = []
    for key, value of @records
      result.push(value)
    result
  # clone
  @cloneArray: (array) ->
    (value.clone() for value in array)

  @idCounter: 0

  @resetIdCounter: ->
    ids        = (model.id for model in @all()).sort((a, b) -> a > b)
    lastID     = ids[ids.length - 1]
    lastID     = lastID?.replace?(/^c-/, '') or lastID
    lastID     = parseInt(lastID, 10)
    @idCounter = (lastID + 1) or 0

  # uidってどこで使うの？
  @uid: (prefix = '') ->
    prefix + @idCounter++

  # ### Instance
  constructor: (atts) ->
    super
#
#    load: (atts) ->
#      for key, value of atts
#        if typeof @[key] is 'function'
#          @[key](value)
#        else
#          @[key] = value
#      this
    @load atts if atts
    # cidが設定されてなければuidメソッドで設定
    # ところでなんで@constructorのメソッドなの？
    @cid or= @constructor.uid('c-')

  isNew: ->
    not @exists()

  isValid: ->
    not @validate()

  validate: ->

  load: (atts) ->
    # 関数だったらvalを引数にして実行。それ以外だったら代入
    for key, value of atts
      if typeof @[key] is 'function'
        @[key](value)
      else
        @[key] = value
    this

  attributes: ->
    result = {}
    # @constructor.attributesの属性のうちthisの属性を選択
    for key in @constructor.attributes when key of this
      if typeof @[key] is 'function'
        result[key] = @[key]()
      else
        result[key] = @[key]
    result.id = @id if @id
    result

# 等しいとは以下の3つの条件を満たす
#
# - recのコンストラクタが等しい
# - cidが等しい
# - idが等しい
#
  eql: (rec) ->
    !!(rec and rec.constructor is @constructor and
        (rec.cid is @cid) or (rec.id and rec.id is @id))
# saveするとerror, beforeSave, saveのトリガー発生
  save: (options = {}) ->
    unless options.validate is false
      error = @validate()
      if error
        @trigger('error', error)
        return false

    @trigger('beforeSave', options)
    # 新しければcreateそうでなければupdate
    record = if @isNew() then @create(options) else @update(options)
    @trigger('save', options)
    record

  updateAttribute: (name, value, options) ->
    @[name] = value
    @save(options)

  updateAttributes: (atts, options) ->
    @load(atts)
    @save(options)

  changeID: (id) ->
    records = @constructor.records
    records[id] = records[@id]
    delete records[@id]
    @id = id
    @save()

# deleteする前とあとに計3つのトリガー
#
# recordsとcrecordsが削除される
#
# ついでにunbindもされる
  destroy: (options = {}) ->
    @trigger('beforeDestroy', options)
    delete @constructor.records[@id]
    delete @constructor.crecords[@cid]
    @destroyed = true
    @trigger('destroy', options)
    @trigger('change', 'destroy', options)
    @unbind()
    this

  dup: (newRecord) ->
    # これがわからん
    result = new @constructor(@attributes())
    if newRecord is false
      result.cid = @cid
    else
      delete result.id
    result

  clone: ->
    Object.create(@)

  reload: ->
    return this if @isNew()
    original = @constructor.find(@id)
    @load(original.attributes())
    original

  toJSON: ->
    @attributes()

  toString: ->
    "<#{@constructor.className} (#{JSON.stringify(@)})>"

  # これはどこで使うんだ？
  fromForm: (form) ->
    result = {}
    for key in $(form).serializeArray()
      result[key.name] = key.value
    @load(result)

# 存在するとは
# idが存在して@constructor.recordsにあること
  exists: ->
    @id && @id of @constructor.records

# ### Private

# 前後にトリガー
# クローンを返す
  update: (options) ->
    @trigger('beforeUpdate', options)
    records = @constructor.records
    records[@id].load @attributes()
    clone = records[@id].clone()
    clone.trigger('update', options)
    clone.trigger('change', 'update', options)
    clone

# 前後にトリガー
# クローンを返す
  create: (options) ->
    @trigger('beforeCreate', options)
    @id          = @cid unless @id

    record       = @dup(false)
    @constructor.records[@id]   = record
    @constructor.crecords[@cid] = record

    clone        = record.clone()
    clone.trigger('create', options)
    clone.trigger('change', 'create', options)
    clone

  bind: (events, callback) ->
    @constructor.bind events, binder = (record) =>
      if record && @eql(record)
        callback.apply(@, arguments)
    @constructor.bind 'unbind', unbinder = (record) =>
      if record && @eql(record)
        @constructor.unbind(events, binder)
        @constructor.unbind('unbind', unbinder)
    binder

  one: (events, callback) ->
    binder = @bind events, =>
      @constructor.unbind(events, binder)
      callback.apply(@)

  trigger: (args...) ->
    args.splice(1, 0, @)
    @constructor.trigger(args...)

  unbind: ->
    @trigger('unbind')

# # Controller
class Controller extends Module
  @include Events
  @include Log

  eventSplitter: /^(\S+)\s*(.*)$/
  # デフォルトのタグ
  tag: 'div'

  constructor: (options) ->
    @options = options

    for key, value of @options
      @[key] = value

    # elが設定されてない場合にはdivが使われる
    @el = document.createElement(@tag) unless @el
    @el = $(@el)

    # className,attributesがあれば@elに追加される
    @el.addClass(@className) if @className
    @el.attr(@attributes) if @attributes

    # なんのために用意されているの？
    @release -> @el.remove()

    # わからん
    @events = @constructor.events unless @events
    @elements = @constructor.elements unless @elements
    # わからん
    @delegateEvents(@events) if @events
    @refreshElements() if @elements

    super

  release: (callback) =>
    # callbackに関数が与えられたらbindでそうじゃなかったらトリガー
    if typeof callback is 'function'
      @bind 'release', callback
    else
      @trigger 'release'
  # @el内を探す
  $: (selector) -> $(selector, @el)

  # イベントの委譲
  delegateEvents: (events) ->
    for key, method of events
      # methodが関数ではない場合、proxy
      #
      #  　 @proxy: (func) ->
      #     => func.apply(@, arguments)
      #
      unless typeof(method) is 'function'
        method = @proxy(@[method])

      match      = key.match(@eventSplitter)
      eventName  = match[1]
      selector   = match[2]

# セレクタが指定されていなければイベントにメソッドをバインドする
#
# セレクタが指定されていれば、委譲する
# delegateメソッドは[jQueryのメソッド](http://api.jquery.com/delegate/)
#
      if selector is ''
        @el.bind(eventName, method)
      else
        @el.delegate(selector, eventName, method)

  # リフレッシュ
  refreshElements: ->
    for key, value of @elements
      @[value] = @$(key)
  # 関数の実行時間を遅らせる
  delay: (func, timeout) ->
    setTimeout(@proxy(func), timeout || 0)
  # htmlを出力
  html: (element) ->
    @el.html(element.el or element)
    @refreshElements()
    @el

  # ### jQueryのメソッドを拡張してるだけ
  append: (elements...) ->
    elements = (e.el or e for e in elements)
    @el.append(elements...)
    @refreshElements()
    @el

  appendTo: (element) ->
    @el.appendTo(element.el or element)
    @refreshElements()
    @el

  prepend: (elements...) ->
    elements = (e.el or e for e in elements)
    @el.prepend(elements...)
    @refreshElements()
    @el

  replace: (element) ->
    [previous, @el] = [@el, $(element.el or element)]
    previous.replaceWith(@el)
    @delegateEvents(@events)
    @refreshElements()
    @el

# # Utilities & Shims

$ = window?.jQuery or window?.Zepto or (element) -> element

unless typeof Object.create is 'function'
  Object.create = (o) ->
    Func = ->
    Func.prototype = o
    new Func()

isArray = (value) ->
  Object::toString.call(value) is '[object Array]'

isBlank = (value) ->
  return true unless value
  return false for key of value
  true

makeArray = (args) ->
  Array::slice.call(args, 0)

# # Globals

Spine = @Spine   = {}
module?.exports  = Spine

Spine.version    = '1.0.6'
Spine.isArray    = isArray
Spine.isBlank    = isBlank
Spine.$          = $
Spine.Events     = Events
Spine.Log        = Log
Spine.Module     = Module
Spine.Controller = Controller
Spine.Model      = Model

# # Global events

Module.extend.call(Spine, Events)

# # JavaScript compatability

Module.create = Module.sub =
  Controller.create = Controller.sub =
    Model.sub = (instances, statics) ->
      class result extends this
      result.include(instances) if instances
      result.extend(statics) if statics
      result.unbind?()
      result

Model.setup = (name, attributes = []) ->
  class Instance extends this
  Instance.configure(name, attributes...)
  Instance

# なにこれ？
Module.init = Controller.init = Model.init = (a1, a2, a3, a4, a5) ->
  new this(a1, a2, a3, a4, a5)

Spine.Class = Module
