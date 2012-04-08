Spine ?= require('spine')

Spine.Model.Local =
  # ４つのメソッドを拡張
  extended: ->
    @change @saveLocal
    @fetch @loadLocal

  # 自分をJSON文字列化してlocalStorageに突っ込む
  saveLocal: ->
    result = JSON.stringify(@)
    localStorage[@className] = result

  # saveLocalの逆
  loadLocal: ->
    result = localStorage[@className]
    @refresh(result or [], clear: true)

module?.exports = Spine.Model.Local