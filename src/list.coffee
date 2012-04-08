# 定義されてなかったらrequire
Spine ?= require('spine')
$      = Spine.$

# Spine.Controllerを継承
class Spine.List extends Spine.Controller
  events:
    'click .item': 'click'

  selectFirst: false

  constructor: ->
    super
    @bind 'change', @change
  # 上書き必要
  template: ->
    throw 'Override template'

  change: (item) =>
    @current = item

    unless @current
      @children().removeClass('active')
      return

    @children().removeClass('active')
    $(@children().get(@items.indexOf(@current))).addClass('active')
  # render
  render: (items) ->
    @items = items if items
    # templateかぶせてhtmlにする
    @html @template(@items)
    # changeを呼び出す
    @change @current
    # わからん
    if @selectFirst
      unless @children('.active').length
        @children(':first').click()
　# [jQuery chirdren](http://api.jquery.com/children/)
  children: (sel) ->
    @el.children(sel)

  click: (e) ->
    item = @items[$(e.currentTarget).index()]
    @trigger('change', item)
    true

module?.exports = Spine.List