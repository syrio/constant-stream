# Server-side Code
helpers = require('helpers')

storage = new helpers.StreamStorage
online = new helpers.OnlineDataManager(storage)
offline = new helpers.OfflineDataManager(storage)
channel = new helpers.OnlineChannelManager(storage)
session_manager = new helpers.SessionManager(storage)

session_manager.on 'timeout', (session_id) ->
  current_sessions[session_id]?.irc?.disconnect?()
  delete current_sessions[@session.id]

session_manager.on 'reconnect', (session) ->
  # ask for updated members list for each channel upon reconnection of an online session
  # when the server will return, IrcStream (irc_client) will fire the 'names' event and handlers we set in actions.init will be fired
  irc_client = current_sessions[session?.id]?.irc
  return unless irc_client?
  for channel in session.channels
    irc_client.names channel

  
current_sessions = {}

exports.actions =
  
  init: (user, cb) ->

    # no real need for authentication, just using SocketStream baked-in users pub sub for publishing session specific events
    @session.setUserId(@session.id)
    
    # metaprogramming the events and handlers to match one another by the members of the Manger classes is defiantly a possibility
    channel_handlers =
      newMember:      [channel.handleNewMember],
      leavingMember:  [channel.handleLeavingMember],
      changingMember: [channel.handleChangingMember],
      currentTopic:   [channel.handleCurrentTopic],
      currentMembers: [channel.handleCurrentMembers]
    channel_observer = new helpers.ChannelObserver(channel_handlers, @session)
    session_observer = new helpers.SessionObserver(session_manager, @session)
    data_observer = new helpers.DataObserver({ 
      newData: [online.handleNewData, offline.handleNewData],
      newPrivateData: [online.handleNewPrivateData, offline.handleNewPrivateData]}, @session)
    
    # if user reloaded it's browser, assume he wants to start over, disconnect his irc connection and connect a new one
    if current_sessions[@session.id]?
      if current_sessions[@session.id].irc?
        current_sessions[@session.id].disconnect?()
      delete current_sessions[@session.id]

    session = @session
    
    irc_client = new helpers.StreamIrc SS.config.irc.server, user, (err) ->
      return cb { error: err, message: "Could not connect to irc server: #{err}" } if err? 
      cb { message: "Ready!" }
      irc_client.members (channel, members) ->
        channel_observer.observedCurrentMembers session, { channel: channel, members: members }
      irc_client.topic (channel, topic) ->
        channel_observer.observedCurrentTopic session, { channel: channel, topic: topic }
      irc_client.private (from, message) ->
        data_observer.observedNewPrivateData session, { message: { text: message, from: from } }
    
    current_sessions[@session.id] = 
      irc: irc_client, channel_observer: channel_observer, session_observer: session_observer, data_observer: data_observer

  
  # Quick Chat Demo
  sendMessage: (channel, message, cb) ->
    # make sure session and irc client are good
    irc_client = current_sessions[@session.id]?.irc
    return cb false unless irc_client?

    irc_client.say(channel, message)
    cb true

  joinChannel: (channel, cb) ->
    
    irc_client = current_sessions[@session.id]?.irc
    channel_observer = current_sessions[@session.id].channel_observer
    data_observer = current_sessions[@session.id].data_observer
    # make sure session objects are good    
    return cb false unless irc_client? and channel_observer? and data_observer?
    
    bare_channel = channel.replace(/@|#/, '')
    
    @session.channel.subscribe channel
    
    session = @session
    
    irc_client.new_member channel, (channel, new_member) ->
      channel_observer.observedNewMember session, { channel: channel, member: new_member }
    irc_client.leaving_member channel, (channel, leaving_member) ->
      channel_observer.observedLeavingMember session, { channel: channel, member: leaving_member } 
    irc_client.changing_member channel, (channel, old_name, new_name) ->
        channel_observer.observedChangingMember session, { channel: channel, member: new_name: new_name, old_name: old_name }
    irc_client.join channel, (from, message) ->
      data_observer.observedNewData session, { channel: channel, message: { text: message, user: from } }
      
    cb true
    
  leaveChannel: (channel, cb) ->
    
    # leave IRC channel
    irc_client = current_sessions[@session.id]?.irc
    irc_client?.leave channel

    # unsubscribe from the SocketStream channel matching this IRC channel
    @session.channel.unsubscribe channel


    cb true
