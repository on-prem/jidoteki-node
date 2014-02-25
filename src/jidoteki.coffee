# Description:
#   Build virtual appliances using Jidoteki
#   https://jidoteki.com
#   Copyright (c) 2014 Alex Williams, Unscramble <license@unscramble.jp>

###
 * Jidoteki - https://jidoteki.com
 * Build virtual appliances using Jidoteki
 * Copyright (c) 2014 Alex Williams, Unscramble <license@unscramble.jp>
###

crypto    = require 'crypto'
armrest   = require 'armrest'

settings  =
  endpoint:   'https://api.jidoteki.com'
  userid:     process.env.JIDOTEKI_USERID || 'change me'
  apikey:     process.env.JIDOTEKI_APIKEY || 'change me'
  useragent:  'nodeclient-jidoteki/0.1.6'
  token:      null

api       = armrest.client settings.endpoint

exports.settings = settings

exports.makeHMAC = (string, callback) ->
  callback crypto
    .createHmac('sha256', settings.apikey)
    .update(string)
    .digest 'hex'

exports.getToken = (callback) ->
  resource = '/auth/user'
  this.makeHMAC "POST#{settings.endpoint}#{resource}", (signature) ->
    api.post
      url: resource
      headers:
        'X-Auth-Uid': settings.userid
        'X-Auth-Signature': signature
        'User-Agent': settings.useragent
        'Accept-Version': 1
        'Content-Type': 'application/json'
      complete: (err, res, data) ->
        if data.status is 'success'
          settings.token = data.content
          setTimeout ->
            settings.token = null
          , 27000000 # Expire the token after 7.5 hours
        callback data

exports.getData = (resource, callback) ->
  this.makeHMAC "GET#{settings.endpoint}#{resource}", (signature) ->
    api.get
      url: resource
      headers:
        'X-Auth-Token': settings.token
        'X-Auth-Signature': signature
        'User-Agent': settings.useragent
        'Accept-Version': 1
      complete: (err, res, data) ->
        if err
          settings.token = null if data.status is 'error' and data.message is 'Unable to authenticate'
        callback data

exports.postData = (resource, string, callback) ->
  this.makeHMAC "POST#{settings.endpoint}#{resource}#{JSON.stringify(string)}", (signature) ->
    api.post
      url: resource
      params: string
      headers:
        'X-Auth-Token': settings.token
        'X-Auth-Signature': signature
        'User-Agent': settings.useragent
        'Accept-Version': 1
        'Content-Type': 'application/json'
      complete: (err, res, data) ->
        if err
          settings.token = null if data.status is 'error' and data.message is 'Unable to authenticate'
        callback data

exports.makeRequest = (requestMethod, resource, string..., callback) =>
  method = requestMethod.toUpperCase()

  apiCall = =>
    switch method
      when "GET"
        this.getData resource, (result) -> callback result
      when "POST"
        this.postData resource, string[0], (result) -> callback result

  if settings.token?
    apiCall()
  else
    this.getToken (result) =>
      if result.status is 'success'
        apiCall()
      else
        callback result
