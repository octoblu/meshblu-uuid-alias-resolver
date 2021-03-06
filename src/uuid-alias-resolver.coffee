_ = require 'lodash'
async = require 'async'
request = require 'request'
UUID_REGEX = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/i

class UUIDAliasResolver
  constructor: ({@cache, @aliasServerUri}) ->
    @aliasServerUri = undefined if @aliasServerUri == ''

  resolve: (alias, callback) =>
    return callback null, alias if alias == '*'
    return callback null, alias if UUID_REGEX.test alias
    return callback null, alias unless @aliasServerUri?

    @_getAliasOrCache alias, (error, uuid) =>
      return callback error if error?
      callback null, uuid

  reverseLookup: (uuid, callback) =>
    return callback null unless @aliasServerUri?
    @_getReverseLookupOrCache uuid, (error, aliases) =>
      return callback error if error?
      callback null, aliases

  _cacheAlias: (alias, uuid, callback) =>
    @cache.setex "alias:#{alias}", 30, JSON.stringify(uuid: uuid), callback

  _getCache: (alias, callback) =>
    @cache.get "alias:#{alias}", (error, result) =>
      return callback error if error?
      return callback null unless result?
      return callback null, JSON.parse result

  _cacheReverseLookup: (uuid, aliases, callback) =>
    @cache.setex "alias:reverse:#{uuid}", 30, JSON.stringify(aliases: aliases), callback

  _getReverseLookupCache: (uuid, callback) =>
    @cache.get "alias:reverse:#{uuid}", (error, result) =>
      return callback error if error?
      return callback null unless result?
      return callback null, JSON.parse result

  _getAlias: (alias, callback) =>
    path = @aliasServerUri + "/?name=#{alias}"

    request.get path, json: true, (error, response, body) =>
      uuid = body?.uuid
      @_cacheAlias alias, uuid, (cacheError) =>
        return callback error if error?
        return callback error if cacheError?
        callback null, uuid

  _getAliasOrCache: (alias, callback) =>
    @_getCache alias, (error, result) =>
      return callback error if error?
      return callback null, result.uuid if result?.uuid?

      @_getAlias alias, (error, uuid) =>
        return callback error if error?
        return callback null, uuid if uuid?

        return callback null, alias

  _getReverseLookupOrCache: (uuid, callback) =>
    @_getReverseLookupCache uuid, (error, result) =>
      return callback error if error?
      return callback null, result.aliases if result?

      @_getReverseLookup uuid, (error, aliases) =>
        return callback error if error?
        callback null, aliases

  _getReverseLookup: (uuid, callback) =>
    path = @aliasServerUri + "/aliases/#{uuid}"

    request.get path, json: true, (error, response, body) =>
      return callback error if error?

      @_cacheReverseLookup uuid, body, (error) =>
        return callback error if error?
        callback null, body

module.exports = UUIDAliasResolver
