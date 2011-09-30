sinon = require('sinon')
sinon_jasmine = require('../../sinon-jasmine')
helpers = require('helpers')
irc = require('irc')


describe 'Server helpers', ->
  
  describe 'StreamIrc', ->
    describe 'Upon initialization', ->
      afterEach -> 
        irc.Client.restore()
      it 'should create a new irc network client', ->
        client = sinon.stub(irc, 'Client')
        stream_irc = new helpers.StreamIrc('some_server', 'some_user')
        expect(client).toHaveBeenCalledWith('some_server', 'some_user')
      it 'should bind the provided optional callback to the irc client connection success and error events', ->
        on_spy = sinon.spy()
        cb = ->
        sinon.stub(irc, 'Client').returns(on:on_spy)
        stream_irc = new helpers.StreamIrc('some_server', 'some_user', cb)
        expect(on_spy).toHaveBeenCalledWith('connect', cb)
        expect(on_spy).toHaveBeenCalledWith('error', cb)
    
    describe 'Disconnecting from the server', ->
      afterEach -> 
        irc.Client.restore()      
      it 'should leave the server gracefully', ->
        client = { disconnect: sinon.spy(), on: sinon.spy() }
        sinon.stub(irc, 'Client').returns(client)
        stream_irc = new helpers.StreamIrc('some_server', 'some_user', ->)
        stream_irc.disconnect()
        expect(client.disconnect).toHaveBeenCalled()
        
    describe 'Joining a channel', ->
      beforeEach ->
        @client = join: sinon.spy(), addListener: sinon.spy(), send: sinon.spy()
        sinon.stub(irc, 'Client').returns(@client)
        @org_setInterval = setInterval
        global.setInterval = sinon.spy()
        @receivedMessage = (from, message) ->
        stream_irc = new helpers.StreamIrc('some_server', 'some_user')
        stream_irc.join('some_channel', @receivedMessage)
        stream_irc.join('#another_channel', @receivedMessage)        
      afterEach -> 
        irc.Client.restore()
        global.setInterval = @org_setInterval
      it 'should join the irc channel if no hashtag was provided', ->
        expect(@client.join).toHaveBeenCalledWith('#some_channel')
      it 'should join an irc channel if a hahstag ws provided', ->
        expect(@client.join).toHaveBeenCalledWith('#another_channel')        
      it 'should listen to messages on the joined irc channel', ->
        expect(@client.addListener).toHaveBeenCalledWithExactly('message#some_channel', @receivedMessage)
      it 'should set a names fetcher to run every set interval', ->
        expect(setInterval).toHaveBeenCalled()
        
    describe 'Leaving a channel', ->
      beforeEach ->
        @client = part: sinon.spy(), removeAllListeners: sinon.spy()
        sinon.stub(irc, 'Client').returns(@client)
        stream_irc = new helpers.StreamIrc('some_server', 'some_user')
        stream_irc.leave('some_channel', ->)
        stream_irc.leave('#another_channel', ->)
      afterEach -> 
        irc.Client.restore()  
      it 'should leave the irc channel if no hashtag was provided', ->
        expect(@client.part).toHaveBeenCalledWith('#some_channel')
      it 'should leave an irc channel if a hahstag ws provided', ->
        expect(@client.part).toHaveBeenCalledWith('#another_channel')        
      it 'should remove channel specific listenrs', ->
        expect(@client.removeAllListeners).toHaveBeenCalledWith('join#some_channel')
        expect(@client.removeAllListeners).toHaveBeenCalledWith('join#another_channel')
        expect(@client.removeAllListeners).toHaveBeenCalledWith('message#some_channel')
        expect(@client.removeAllListeners).toHaveBeenCalledWith('message#another_channel')
        
    describe 'Saying a message', ->
      afterEach ->
        irc.Client.restore()
      it 'should send it to the irc channel', ->
        @client = say: sinon.spy()
        sinon.stub(irc, 'Client').returns(@client)
        stream_irc = new helpers.StreamIrc('some_server', 'some_user')
        stream_irc.say('some_channel', 'some_message')
        expect(@client.say).toHaveBeenCalledWithExactly('some_channel', 'some_message')
    
    describe 'Excplicitly request the members names of the given chanel', ->
      afterEach ->
        irc.Client.restore()
      it 'should send the request to the irc channel', ->
        @client = send: sinon.spy()
        sinon.stub(irc, 'Client').returns(@client)
        stream_irc = new helpers.StreamIrc('some_server', 'some_user')
        stream_irc.names('some_channel')
        expect(@client.send).toHaveBeenCalledWithExactly('NAMES', '#some_channel')

    describe 'Subscribing to an event', ->
      beforeEach ->
        @on_spy = sinon.spy()
        sinon.stub(irc, 'Client').returns({on:@on_spy})
        @stream_irc = new helpers.StreamIrc()
        @handler = ->        
      afterEach ->
        irc.Client.restore()
      it 'should bind the given handler to the given event', ->
        @stream_irc.on('some_event', @handler)        
        expect(@on_spy).toHaveBeenCalledWith('some_event', @handler)    
      it 'should allow chaining of binding, jQuery style', ->
        @stream_irc.on('another_event', @handler).on('different_event', @handler)
        expect(@on_spy).toHaveBeenCalledWith('another_event', @handler)
        expect(@on_spy).toHaveBeenCalledWith('different_event', @handler)

    describe 'Getting a new private message notfication', ->
      beforeEach ->
        @on_fake = (event, on_handler) ->
          if 'pm' == event
            on_handler('private_sender', 'some_private_message')
        sinon.stub(irc, 'Client').returns({on:@on_fake})
        @stream_irc = new helpers.StreamIrc()
        @handler = sinon.spy()
      afterEach ->
        irc.Client.restore()
      it 'should call the given handler with the sender and the message text', ->
        @stream_irc.private(@handler)
        expect(@handler).toHaveBeenCalledWithExactly('private_sender', 'some_private_message' )
    
    describe 'Getting current channel members notification', ->
      beforeEach ->
        @on_fake = (event, handler) ->
          if 'names' == event
            handler('#some_chan', { 'some_nick' : '@', 'another_nick' : '',  '' : '' } )
        sinon.stub(irc, 'Client').returns({on:@on_fake})
        @orgClearInterval = clearInterval
        global.clearInterval = sinon.spy()
        @stream_irc = new helpers.StreamIrc()
        @stream_irc.channels = '#some_chan': names_fetcher_id : 12345
        @handler = sinon.spy()
      afterEach ->
        irc.Client.restore()
        global.clearInterval = @orgClearInterval
      it 'should call the given handler with the bare channel name and fully qualified members names', ->
        @stream_irc.members(@handler)
        expect(@handler).toHaveBeenCalledWith('some_chan')
        members = @handler.args[0][1]
        expect(members[0].name).toEqual('@some_nick')
        expect(members[1].name).toEqual('another_nick')
      it 'should clear the members names fetcher that was executed to run per interval on @join (if it exists)', ->
        @stream_irc.members(@handler)
        expect(clearInterval).toHaveBeenCalledWith(12345)
        expect(@stream_irc.channels['#some_chan']?.names_fetcher_id).toBeUndefined()
        
        
    describe 'Getting current topic notification', ->
      beforeEach ->
        @on_fake = (event, handler) ->
          if 'topic' == event
            handler('#some_chan', 'some_topic')
        sinon.stub(irc, 'Client').returns({on:@on_fake})
        @stream_irc = new helpers.StreamIrc()
        @handler = sinon.spy()
      afterEach ->
        irc.Client.restore()
      it 'should call the given handler with the bare channel name and the topic', ->
        @stream_irc.topic(@handler)
        expect(@handler).toHaveBeenCalledWithExactly('some_chan', 'some_topic')

    describe 'Getting a new member joined notification', ->
      beforeEach ->
        @on_fake = (event, on_handler) ->
          if 'join#some_chan' == event
            on_handler('joined_member')
        sinon.stub(irc, 'Client').returns({on:@on_fake})
        @stream_irc = new helpers.StreamIrc()
        @handler = sinon.spy()
      afterEach ->
        irc.Client.restore()
      it 'should call the given handler with the bare channel name and the joined member name', ->
        @stream_irc.new_member('some_chan', @handler)
        expect(@handler).toHaveBeenCalledWithExactly('some_chan', { name: 'joined_member' } )

    describe 'Getting a leaving member notification', ->
      beforeEach ->
        on_fake = (event, on_handler) ->
          if 'part' == event
            on_handler('#some_chan', 'leaving_member', 'some_leaving_reason')
        sinon.stub(irc, 'Client').returns({on:on_fake})
        @stream_irc = new helpers.StreamIrc()
        @handler = sinon.spy()
      afterEach ->
        irc.Client.restore()
      it 'should call the given handler with the bare channel name and the leaving member name', ->
        @stream_irc.leaving_member('some_chan', @handler)
        expect(@handler).toHaveBeenCalledWith('some_chan', {name:'leaving_member'})

    describe 'Getting a member changing name notification', ->
      beforeEach ->
        on_fake = (event, on_handler) ->
          if 'nick' == event
            on_handler('before_change_member_name', 'after_change_member_name', ['#another_chan', '#some_chan'])
        sinon.stub(irc, 'Client').returns({on:on_fake})
        @stream_irc = new helpers.StreamIrc()
        @handler = sinon.spy()
      afterEach ->
        irc.Client.restore()
      it 'should call the given handler with the bare channel name and the new and old member names', ->
        @stream_irc.changing_member('some_chan', @handler)
        expect(@handler).toHaveBeenCalledWith('some_chan', 'before_change_member_name', 'after_change_member_name')


  describe 'StreamStorage', ->
    describe 'Adding items to a list', ->
      beforeEach ->
        global.R = 
          rpush: sinon.spy()
      afterEach ->
        global.R = {}
      it 'should add them to the underlying storage', ->
        storage = new helpers.StreamStorage()
        storage.lstore('some:list', 'some_item')
        storage.lstore('some:list', 'a_item')
        expect(R.rpush).toHaveBeenCalledWith('some:list', 'some_item')
        expect(R.rpush).toHaveBeenCalledWith('some:list', 'a_item')

    describe 'Removing items from a list', ->
      beforeEach ->
        global.R = 
          type: sinon.stub().yields(0, 'list')
          lrem: sinon.spy()
      afterEach ->
        global.R = {}
      it 'should remove them from the underlying storage', ->
        storage = new helpers.StreamStorage()
        storage.remove('some:list', 'some_item')
        storage.remove('some:list', 'a_item')
        expect(R.lrem).toHaveBeenCalledWith('some:list', 0, 'some_item')
        expect(R.lrem).toHaveBeenCalledWith('some:list', 0, 'a_item')

    describe 'Adding items to a set', ->
      beforeEach ->
        global.R = 
          sadd: sinon.spy()
      afterEach ->
        global.R = {}
      it 'should add them to the underlying storage', ->
        storage = new helpers.StreamStorage()
        storage.sstore('some:set', 'some_item')
        storage.sstore('some:set', 'a_item')
        expect(R.sadd).toHaveBeenCalledWith('some:set', 'some_item')
        expect(R.sadd).toHaveBeenCalledWith('some:set', 'a_item')

    describe 'Removing items from a set', ->
      beforeEach ->
        global.R = 
          type: sinon.stub().yields(0, 'set')
          srem: sinon.spy()
      afterEach ->
        global.R = {}
      it 'should remove them from the underlying storage', ->
        storage = new helpers.StreamStorage()
        storage.remove('some:set', 'some_item')
        storage.remove('some:set', 'a_item')
        expect(R.srem).toHaveBeenCalledWith('some:set', 'some_item')
        expect(R.srem).toHaveBeenCalledWith('some:set', 'a_item')

    describe 'Adding items to a stored set', ->
      beforeEach ->
        global.R = 
          zadd: sinon.spy()
      afterEach ->
        global.R = {}
      it 'should add them to the underlying storage', ->
        storage = new helpers.StreamStorage()
        storage.zstore('some:sorted:set', 1, 'some_item')
        storage.zstore('some:sorted:set', 2 ,'a_item')
        expect(R.zadd).toHaveBeenCalledWith('some:sorted:set', 1, 'some_item')
        expect(R.zadd).toHaveBeenCalledWith('some:sorted:set', 2, 'a_item')

    describe 'Removing items from a sorted set', ->
      beforeEach ->
        global.R = 
          type: sinon.stub().yields(0, 'zset')
          zrem: sinon.spy()
      afterEach ->
        global.R = {}
      it 'should remove them from the underlying storage', ->
        storage = new helpers.StreamStorage()
        storage.remove('some:sorted:set', 'some_item')
        storage.remove('some:sorted:set', 'a_item')
        expect(R.zrem).toHaveBeenCalledWith('some:sorted:set', 'some_item')
        expect(R.zrem).toHaveBeenCalledWith('some:sorted:set', 'a_item')


    describe 'Adding a single string key/value', ->
      beforeEach ->
        global.R = 
          set: sinon.spy()
      afterEach ->
        global.R = {}
      it 'should add it to the underlying storage', ->
        storage = new helpers.StreamStorage()
        storage.store('some:key', 'some_value')
        expect(R.set).toHaveBeenCalledWith('some:key', 'some_value')

    describe 'Removing an entire key', ->
      beforeEach ->
        global.R = 
          type: sinon.stub().yields(0, 'set')
          del: sinon.spy()
      afterEach ->
        global.R = {}
      it 'should remove them from the underlying storage', ->
        storage = new helpers.StreamStorage()
        storage.remove('some:thing')
        expect(R.del).toHaveBeenCalledWith('some:thing')

  describe 'Getting all members from a given set', ->
    beforeEach ->
      global.R = 
        type: sinon.stub().yields(0, 'set')
        smembers: sinon.stub().yields(0, ['some_member', 'a_member'])
    afterEach ->
      global.R = {}
    it 'should callback true if it is', ->
      storage = new helpers.StreamStorage()
      # Vows.js style
      storage.get 'some:set', (err, members) ->
        expect(members[0]).toEqual 'some_member'
        expect(members[1]).toEqual 'a_member'        
        expect(R.smembers).toHaveBeenCalledWith('some:set')

  describe 'Getting all members from a given list', ->
    beforeEach ->
      global.R = 
        type: sinon.stub().yields(0, 'list')
        lrange: sinon.stub().yields(0, ['some_member', 'a_member'])
    afterEach ->
      global.R = {}
    it 'should callback true if it is', ->
      storage = new helpers.StreamStorage()
      # Vows.js style
      storage.get 'some:list', (err, members) ->
        expect(members[0]).toEqual 'some_member'
        expect(members[1]).toEqual 'a_member'        
        expect(R.lrange).toHaveBeenCalledWith('some:list', 0, -1)

  describe 'Getting the value from a given string key', ->
    beforeEach ->
      global.R = 
        type: sinon.stub().yields(0, 'string')
        get: sinon.stub().yields(0, 'some_value')
    afterEach ->
      global.R = {}
    it 'should callback true if it is', ->
      storage = new helpers.StreamStorage()
      # Vows.js style
      storage.get 'some:key', (err, value) ->
        expect(value).toEqual 'some_value'
        expect(R.get).toHaveBeenCalledWith('some:key')

  describe 'Checking if a given value is a member of a given set', ->
    beforeEach ->
      global.R = 
        sismember: sinon.stub().yields(0, true)
        type: sinon.stub().yields(0, 'set')
    afterEach ->
      global.R = {}
    it 'should callback true if it is', ->
      storage = new helpers.StreamStorage()
      # Vows.js style
      storage.ismember 'some:set', 'some_member', (err, ismember) ->
        expect(ismember).toBeTruthy
        expect(R.sismember).toHaveBeenCalledWith('some:set', 'some_member')

  describe 'Checking if a given value is a member of a given sorted set', ->
    beforeEach ->
      global.R = 
        zscore: sinon.stub().yields(0, 1)
        type: sinon.stub().yields(0, 'zset')
    afterEach ->
      global.R = {}
    it 'should callback true if it is', ->
      storage = new helpers.StreamStorage()
      # Vows.js style
      storage.ismember 'some:sorted:set', 'some_member', (err, ismember) ->
        expect(ismember).toBeTruthy
        expect(R.zscore).toHaveBeenCalledWith('some:sorted:set', 'some_member')


    describe 'Querying for a list of keys that match a simple regex', ->
      beforeEach ->
        global.R = 
          keys: sinon.stub().yields(0, ['some:long:key'])
      afterEach ->
        global.R = {}
      it 'should get us all the keys that match the given regex', ->
        storage = new helpers.StreamStorage()
        # Vows.js style
        storage.keys 'some:long:*', (err, keys) ->
          expect(keys[0]).toEqual 'some:long:key'
          expect(R.keys).toHaveBeenCalledWith('some:long:*')
          
    describe 'Querying for a range of sorted set members that match a given score range', ->
      beforeEach ->
        global.R = 
          zrangebyscore: sinon.stub().yields(0, ['some:sorted:set:member', 'another:sorted:set:member'])
      afterEach ->
        global.R = {}
      it 'should get us all the keys that match the given regex', ->
        storage = new helpers.StreamStorage()
        # Vows.js style
        storage.range 'sorted:set', 0, 1, (err, results) ->
          expect(results[0]).toEqual 'some:sorted:set:member'
          expect(results[1]).toEqual 'another:sorted:set:member'
          expect(R.zrangebyscore).toHaveBeenCalledWith('sorted:set', 0, 1)
        
    describe 'Removing a range of sorted set members that match a given score range', ->
      beforeEach ->
        global.R = 
          zremrangebyscore: sinon.spy()
      afterEach ->
        global.R = {}
      it 'should get us all the keys that match the given regex', ->
        storage = new helpers.StreamStorage()
        storage.remrange 'sorted:set', 0, 1
        expect(R.zremrangebyscore).toHaveBeenCalledWith('sorted:set', 0, 1)
        
  describe 'a DataObserver', ->
    describe 'upon initializition', ->
      beforeEach ->
        @online = new helpers.OnlineDataManager
        @offline = new helpers.OfflineDataManager        
        @observer = new helpers.DataObserver({ 'newData': [@online.handleNewData, @offline.handleNewData] })
      it 'should bind the relevant OnlineDataManager method to the given (newly received message) event', ->
        expect(@observer.listeners('newData')[0]).toEqual(@online.handleNewData)
      it 'should bind the relevant OfflineDataManager method to the given (newly received message) event', ->
          expect(@observer.listeners('newData')[1]).toEqual(@offline.handleNewData)
  

  describe 'a ChannelObserver', ->
    describe 'upon initializition', ->
      beforeEach ->
        @online = new helpers.OnlineChannelManager
        @offline = new helpers.OfflineChannelManager        
        @observer = new helpers.ChannelObserver({ 'newMember': [@online.handleNewMember, @offline.handleNewMember] })
      it 'should bind the relevant OnlineChannelManager method to the given (new member) event', ->
        expect(@observer.listeners('newMember')[0]).toEqual(@online.handleNewMember)
      it 'should bind the relevant OfflineChannelManager method to the given (new member) event', ->
          expect(@observer.listeners('newMember')[1]).toEqual(@offline.handleNewMember)
  
  
  describe 'a SessionObserver', ->
    beforeEach ->
      global.SS = 
        events:
          on: sinon.spy()

    describe 'upon intialization', ->
      beforeEach ->

        # a little spying on our own to access a class method
        @heartbeat_spy = sinon.spy()
        @original_heartbeat = helpers.SessionObserver::observeSessionHeartbeat
        helpers.SessionObserver::observeSessionHeartbeat = @heartbeat_spy

        new helpers.SessionObserver(@session_manager, 1)        
      afterEach ->
        helpers.SessionObserver::observeSessionHeartbeat = @original_heartbeat
        
      it 'should bind a handling function to the session disconnection event', ->
        expect(SS.events.on).toHaveBeenCalledWith('client:disconnect')
      it 'should bind a handling function to the session connection event', ->
        expect(SS.events.on).toHaveBeenCalledWith('client:init')
      it 'should bind a handling function to the session subscribed to a new channel event', ->
        expect(SS.events.on).toHaveBeenCalledWith('channel:subscribe')
      it 'should bind a handling function to the session unsubscribed to an existing channel event', ->
        expect(SS.events.on).toHaveBeenCalledWith('channel:unsubscribe')
      it 'should call the heartbeat observing initialization method to initialize session heartbeat observation', ->
        expect(@heartbeat_spy).toHaveBeenCalled()
    
    describe 'upon setting heartbeat observation', ->
      it 'should emit a heartbeat event every X seconds (where X is given from configuration)', ->
        global.SS.config = offline_expire: timeout: 24*60 , interval: 999
        
        session_manager = 
          handleDisconnect : ->
          handleConnect: ->
          handleSubscribe: -> 
          handleUnsubscribe: ->
          handleHeartbeat: sinon.spy()
        
        clock = sinon.useFakeTimers(1234567890000)
        # our test subject here, observeSessionHeartbeat ,  will be called by the constructor
        new helpers.SessionObserver(session_manager)
        clock.tick(999*1000)
        expect(session_manager.handleHeartbeat).toHaveBeenCalledWith({ start: 1234482488950, end: 1234483488050 })
        clock.restore()
        
  describe 'an OnlineDataManager', ->
    describe 'handling a newly received message (data element)', ->
      it 'should format the event name and publish the message to the given channel of the given user', ->
        global.SS = publish: user: sinon.spy()
        new_message = { channel: 'some_channel', message: { text: 'some_message' } }
        manager = new helpers.OnlineDataManager
        manager.handleNewData({id:1}, new_message)        
        expect(SS.publish.user).toHaveBeenCalledWith(1, 'some_channel:newMessage', { text: 'some_message' })
        
  describe 'handling a newly received private message (data element)', ->
    it 'should format the event name and publish the message to the given user', ->
      global.SS = publish: user: sinon.spy()
      new_private_message = { message: { from: 'some_private_sender', text: 'some_private_message' } }
      manager = new helpers.OnlineDataManager
      manager.handleNewPrivateData({id:1}, new_private_message)        
      expect(SS.publish.user).toHaveBeenCalledWith(1, 'newPrivateMessage', { from: 'some_private_sender', text: 'some_private_message' })        
      
  describe 'an OfflineDataManager', ->
    describe 'handling a newly received message (data element)', ->
      describe 'given the new data is from a channel that an active offline session is subscribed to', ->
        it 'should store that new data in the offline channel messages list correspodning to the channel the new data was received from', ->
          runs ->
            storage = { lstore: sinon.stub(), ismember: sinon.stub().yields(0, true) }
            manager = new helpers.OfflineDataManager(storage)
            new_message = { channel: 'some_channel', message: { text: 'some_message' } }
            manager.handleNewData({id:1}, new_message)
            expect(storage.lstore).toHaveBeenCalledWithExactly('offline:1:some_channel:messages', JSON.stringify({text: 'some_message'}))
    describe 'handling a newly received private message (data element)', ->            
      it 'should store the private message in the offline private messages list', ->
        runs ->
          storage = { lstore: sinon.stub(), ismember: sinon.stub().yields(0, true) }
          manager = new helpers.OfflineDataManager(storage)
          new_private_message = { message: { from: 'some_private_sender', text: 'some_private_message' } }
          manager.handleNewPrivateData({id:1}, new_private_message)
          expect(storage.lstore).toHaveBeenCalledWithExactly('offline:1:private', JSON.stringify(new_private_message.message))

  describe 'an OnlineChannelManager', ->
    describe 'handling a new member notification', ->
      it 'should format the event name and publish the new member name to the given channel subscribers', ->
        global.SS = publish: channel: sinon.spy()
        new_member = { channel: 'some_channel', member: { name: 'some_member' } }
        manager = new helpers.OnlineChannelManager
        manager.handleNewMember(new_member)
        expect(SS.publish.channel).toHaveBeenCalledWith('some_channel', 'some_channel:newMember', { name: 'some_member' })
    describe 'handling a member leaving notification', ->
      it 'should format the event name and publish the leaving member name to the given channel subscribers', ->
        global.SS = publish: channel: sinon.spy()
        leaving_member = { channel: 'some_channel', member: { name: 'leaving_member' } }
        manager = new helpers.OnlineChannelManager
        manager.handleLeavingMember(leaving_member)
        expect(SS.publish.channel).toHaveBeenCalledWith('some_channel', 'some_channel:leavingMember', { name: 'leaving_member' })
    describe 'handling a member changing name notification', ->
      it 'should format the event name and publish the changing member name to the given channel subscribers', ->
        global.SS = publish: channel: sinon.spy()
        changing_member = { channel: 'some_channel', member: { new_name: 'changing_member', old_name: 'some_member' } }
        manager = new helpers.OnlineChannelManager
        manager.handleChangingMember(changing_member)
        expect(SS.publish.channel).toHaveBeenCalledWith('some_channel', 'some_channel:changingMember', changing_member.member)
    describe 'handling a currnet channel topic notifcation', ->
      it 'should format the event name and publish the current topic to the given channel subscribers', ->
        global.SS = publish: channel: sinon.spy()
        current_topic = { channel: 'some_channel', topic: { name: 'some_topic' } }
        manager = new helpers.OnlineChannelManager
        manager.handleCurrentTopic(current_topic)
        expect(SS.publish.channel).toHaveBeenCalledWith('some_channel', 'some_channel:currentTopic', { name: 'some_topic' })
    describe 'handling a currnet channel members notifcation', ->
      it 'should format the event name and publish the current members to the given channel subscribers', ->
        global.SS = publish: channel: sinon.spy()
        current_members = { channel: 'some_channel', members: [ { name: 'some_member' }, { name : 'another_member' } ] }
        manager = new helpers.OnlineChannelManager
        manager.handleCurrentMembers(current_members)        
        expect(SS.publish.channel).toHaveBeenCalledWith('some_channel', 'some_channel:currentMembers', [{name:'some_member'}, {name:'another_member'}])


  describe 'a SessionManager', ->
    
    describe 'upon initialization', ->
      beforeEach ->
        @manager = new helpers.SessionManager(@storage)
      it 'should bind a method to the session reconnect event', ->
        expect(@manager.listeners('reconnect')[0]).toEqual(@manager.handleReconnect)
      it 'should bind a method to the session timeout event', ->
        expect(@manager.listeners('timeout')[0]).toEqual(@manager.handleTimeout)
        
    describe 'new session connection handling', ->
      describe 'and the new connection is of a session with an id that is in the offline sessions list', ->
        it 'should fire a reconnection event ', ->
          runs ->
            @storage = { ismember: sinon.stub().yields(0, true) }
            new_session = {id : 1}
            @manager = new helpers.SessionManager(@storage)
            @manager.emit = sinon.spy()
            @manager.handleConnect(new_session)          
            expect(@manager.emit).toHaveBeenCalledWithExactly('reconnect', {id: 1})
      
    describe 'handling a session disconnection', ->
      it 'should store the session id in the offline sessions list and store the session disconnection time', -> 
        runs ->
          storage = 
            sstore: sinon.spy(), 
            store: sinon.spy(), 
            zstore: sinon.spy(), 
            list: sinon.spy(), 
            get: sinon.stub().yields(0, ['some_channel', 'a_channel'])
            
          disconnected_session = {id : 1}
          clock = sinon.useFakeTimers(1234567890000)
          manager = new helpers.SessionManager(storage)
          manager.handleDisconnect(disconnected_session)
          expect(storage.zstore).toHaveBeenCalledWithExactly('offline:sessions', 1234567890000, 1)
          clock.restore()

    describe 'handling a session reconnection', ->
        beforeEach ->
          global.SS = publish: user: sinon.spy()
          @storage = 
            remove: sinon.spy()
            get: (key, cb) ->
              if key == 'offline:1:some_channel:messages'
                return cb 0, [JSON.stringify({ text: 'some_message' })]
              else if key == 'offline:1:a_channel:messages'
                return cb 0, [JSON.stringify({ text: 'a_message' })]
              else if key == 'offline:1:private'
                return cb 0, [JSON.stringify({ from: 'some_sender',text: 'a_private_message' })]
              else
                return cb()
          @reconnected_session = { id: 1, user_id: 1, channels: ['some_channel', 'a_channel'] }
          @manager = new helpers.SessionManager(@storage)
        it 'should send all of the stored messages that were received while the session was disconnected (offline)', ->
          runs ->
            @manager.handleReconnect(@reconnected_session)
            expect(SS.publish.user).toHaveBeenCalledWith(1, 'some_channel:newMessage', { text: 'some_message' })
            expect(SS.publish.user).toHaveBeenCalledWith(1, 'a_channel:newMessage', { text: 'a_message' })
        it 'should remove all of the stored messages from the messages list', ->
          runs ->
            @manager.handleReconnect(@reconnected_session)
            expect(@storage.remove).toHaveBeenCalledWith('offline:1:a_channel:messages')
        it 'should send all of the stored private messages that were received while the session was disconnected (offline)', ->
          runs ->
            @manager.handleReconnect(@reconnected_session)
            expect(SS.publish.user).toHaveBeenCalledWith(1, 'newPrivateMessage', {from:'some_sender', text:'a_private_message' })
        it 'should remove the private messages from the private messages list', ->
          runs ->
            @manager.handleReconnect(@reconnected_session)
            expect(@storage.remove).toHaveBeenCalledWith('offline:1:private')
        it 'should remove the session from offline sessions', ->
          runs ->
            @manager.handleReconnect(@reconnected_session)
            expect(@storage.remove).toHaveBeenCalledWith('offline:sessions', 1)


    describe 'handling a session channel subscription', ->
      it 'should add the newly subscribed channel to the set of session channels', ->
        @storage = sstore: sinon.spy()
        session = { id: 1 }
        manager = new helpers.SessionManager(@storage) 
        manager.handleSubscribe(session, 'some_channel')        
        expect(@storage.sstore).toHaveBeenCalledWithExactly('session:1:channels', 'some_channel')

    describe 'handling a session channel unsubscription', ->
      it 'should remove the unsubscribed channel from the set of session channels', ->
        @storage = remove: sinon.spy()
        session = { id: 1 }
        manager = new helpers.SessionManager(@storage) 
        manager.handleUnsubscribe(session, 'some_channel')        
        expect(@storage.remove).toHaveBeenCalledWithExactly('session:1:channels', 'some_channel')

    describe 'handling a session heartbeat', ->
      beforeEach ->
        @storage = 
          range: (key, start, end, cb) -> 
            cb(0, ['1', '2'])
          get: (key, cb) -> 
            cb(0, ['1', '2'])  
          
        @emit_spy = sinon.spy()
        manager = new helpers.SessionManager(@storage)
        manager.emit = @emit_spy
        manager.handleHeartbeat({ start: 1234482488950, end: 1234482490049 })
      it 'should emit a timeout event for all sesisons that have not sent a hearbeat since the given period', ->
        expect(@emit_spy).toHaveBeenCalledWith('timeout', '1')
        expect(@emit_spy).toHaveBeenCalledWith('timeout', '2')
      it 'should emit a heartbeat event for the period', ->
        expect(@emit_spy).toHaveBeenCalledWith('hearbeat', { start: 1234482488950, end: 1234482490049 })
        
    describe 'handling a session tiemout', ->
      it 'should remove all session structures from storage', ->
        @storage = remove: sinon.spy(), get: (key, cb) -> cb(0, ['some_channel'])
        manager = new helpers.SessionManager(@storage)
        manager.handleTimeout(1)
        expect(@storage.remove).toHaveBeenCalledWith('offline:sessions', 1)
        expect(@storage.remove).toHaveBeenCalledWith('offline:1:some_channel:messages')        
        expect(@storage.remove).toHaveBeenCalledWith('session:1:channels')
