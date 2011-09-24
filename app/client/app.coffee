# Client-side Code

# Bind to socket events
SS.socket.on 'disconnect', ->  
  $('#response').removeClass().addClass('error').text('SS server is down :-(')
SS.socket.on 'reconnect', ->   $('#response').removeClass().addClass('success').text('SS server is up :-)')

# Monkeypatch an event removal method to SocketStream events object # (executed upon leaving a channel)
SS.events.remove = (name) ->
  # prevent events object array from swallowing with undeeded event listeners
  delete @_events[name]

# This method is called automatically when the websocket connection is established. Do not rename/delete
exports.init = ->
  
  name_strip = (name) ->
    name.replace /\.|\+|@|#/g, ''
  
  subscribe_to_channel_events =  (channel, user) ->
    
    class MembersCache 
      constructor: ->
        @cache = {}
      add: (member) ->
        @cache[member] = ''
      in: (member) ->
        @cache[member]?
      clearall: ->
        @cache = {}
      clear: (member) ->
        delete @cache[member]
        
    existing_members_names = new MembersCache()
    bare_channel = name_strip channel
    channel_ui = $(".tabs-content.#{bare_channel}.channel")
    
    SS.events.on "#{channel}:newMessage", (message) ->
      message_view = $("<p><strong>#{message.user}:</strong> #{message.text}</p>")
      chatlog = channel_ui.find('.chatlog')
      message_view.appendTo(chatlog)

      # dont annoy user while he is obviously reading by suddenly moving the scroll bar to the bototm
      unless Math.abs(chatlog[0].scrollHeight - chatlog[0].scrollTop) > 350 
        # none moved the scroll bar to a custom location up away (i.e further than 350), so scroll down
        chatlog[0].scrollTop = chatlog[0].scrollHeight
      
      set_tab_unread(channel, 'channel')
      
    SS.events.on "#{channel}:newMember", (member) ->
      return if member.name == user
      return if existing_members_names.in(member.name)
      # add to cache
      existing_members_names.add member.name
      # show on UI
      channel_ui.find('.members-items-list').append($('#tabs-members').tmpl(member:member))

    SS.events.on "#{channel}:leavingMember", (member) ->
      return unless existing_members_names.in(member.name)
      # clear from cache
      existing_members_names.clear member.name
      # delte member from the members list by fading out and removing when the fade out ends
      channel_ui.find('.members-items-list').find("li:contains(#{member.name})").fadeOut(-> $(this).remove())

    SS.events.on "#{channel}:changingMember", (member) ->
      return unless existing_members_names.in(member.old_name)
      # delte member from the members list by fading out and removing when the fade out ends
      channel_ui.find('.members-items-list').find("a:contains(#{member.old_name})").fadeToggle(-> $(this).text("#{member.new_name}").fadeToggle())

    SS.events.on "#{channel}:currentTopic", (topic) =>
      formatted_topic = topic.replace(/\n/g, '').slice(0, 145) + ' ...'
      channel_ui.find('.topic').text formatted_topic

    SS.events.on "#{channel}:currentMembers", (members) =>
      # clear cache entries as a full updated list just arrived
      existing_members_names.clearall()
      
      member_ui_list_html = ''
      for member in members
        unless existing_members_names.in(member.name)
          member_ui_list_html += "<li>#{$('#tabs-members').tmpl(member:member).html()}</li>"
          # add to cache
          existing_members_names.add member.name
      # show on UI
      channel_ui.find('.members-items-list').replaceWith("<ul class='members-items-list'>#{member_ui_list_html}</ul>")

  
  show_tab = (name, type) ->
    $('.visible').removeClass('visible')
    bare_name = name_strip(name)
    invisible_tab = $(".tabs-content.#{bare_name}.#{type}")
    invisible_tab.addClass('visible')
    invisible_tab.find('.message').focus()
    
    # remove the unread styling on the tab link (if it exsits)
    $(".tabs-link.#{bare_name}.#{type}").css('color', '#999')
  
  update_tab_list = ->
    # bind a handler for clicking on a the channel in the channels names tabs-list
    $('.tabs a').unbind('click')    
    $('.tabs a').click (event) ->
      
      # deal with the small closing x on the right side of the channel name
      event_text = event.target.text
      unless event_text?
        return
  
      tab_name = event_text.split(' ')[0]
      bare_tab_name = name_strip(tab_name)
      
      target = $(event.target)
      
      type = 'private' if target.hasClass 'private'
      type = 'channel' if target.hasClass 'channel'

      # make the chatbox visible after user clicked on the channel name in the channels names tab-list
      show_tab(bare_tab_name, type)

    $('.tabs-close').unbind('click')
    $('.tabs-close').click (event) ->

      # stop event from getting to the above '.tabs a' click handler.
      # this sperates clicking 'x' to close tab from switching tabs
      event.stopPropagation()
      
      target = $(event.target)
      type = 'private' if target.parent().hasClass 'private'
      type = 'channel' if target.parent().hasClass 'channel'
      
      tabs_link = target.parent('.tabs-link')
      channel = tabs_link.text().split(' ')[0]
      bare_channel = name_strip(channel)

      SS.server.app.leaveChannel channel, (success) ->
        return unless success

        SS.events.remove "#{bare_channel}:newMessage"
        SS.events.remove "#{bare_channel}:newMember"
        SS.events.remove "#{bare_channel}:leavingMember"
        SS.events.remove "#{bare_channel}:changingMember"        
        SS.events.remove "#{bare_channel}:currentMembers"
        SS.events.remove "#{bare_channel}:currentTopic"

        prev_tab = tabs_link.prev()
        prev_tab = tabs_link.next() if prev_tab.length == 0
        
        tabs_link.remove()
        target.remove()

        $(".tabs-content.#{bare_channel}.#{type}").remove()
        
        leaving_status = if type == 'private' then 'chat with ' else 'channel #'
        status = "Left #{leaving_status}#{bare_channel}"
        $('#status').removeClass().addClass('success').text(status)
        
        new_channel = prev_tab.text().split(' ')[0]
        new_bare_channel = name_strip(new_channel)
        
        prev_type = 'private' if prev_tab.hasClass 'private'
        # last one wins, but there really shouldn't be a situation where a tab has both 'private' and 'channel' types
        prev_type = 'channel' if prev_tab.hasClass 'channel'
        
        show_tab(new_bare_channel, prev_type)
  
  add_tab_chatbox_handler = (channel, user, type) ->
    
    bare_channel = name_strip(channel)
    destination = channel.replace(/\+|@/, '') # replace for sending to ops users, don't touch '#' or '.' for channels
    
    form = $(".tabs-content.#{bare_channel}.#{type}")
    # handle submiting a new message in the channel chatbox
    form.submit ->
      message = form.find('.message').val()
      if message.length > 0
        # send the message by calling a SocketStream server-side exposed method
        SS.server.app.sendMessage destination, message, (success) ->
          if success
            form.find('.message').val('')
            chatlog = form.find('.chatlog')
            $("<p><strong>#{user}:</strong> #{message}</p>").appendTo(chatlog)
            chatlog[0].scrollTop = chatlog[0].scrollHeight        # scroll down
            
          else $('#status').removeClass().addClass('error').text('Unable to send message')
      else
        $('#status').removeClass().addClass('error').text('Oops! You must type a message first')
    

  create_tab = (name, user, type) ->
    bare_name = name_strip(name)

    tab_nav = $('#tabs-nav').tmpl(channel: name)
    tab_nav.addClass("#{bare_name}")
    tab_nav.addClass(type)
    $('.tabs').append(tab_nav)

    tab_content = $('#tabs-content').tmpl()
    tab_content.addClass("#{bare_name}")
    tab_content.addClass(type)
    $('#tabs').append(tab_content)

    add_tab_chatbox_handler name, user, type
    add_tab_members_handler name, user
  
  create_channel_tab = (channel, user) ->
    create_tab channel, user, 'channel'
    
  create_private_tab = (member, user) ->
    create_tab member, user, 'private'

  is_there_such_channel_tab = (tab) ->
    tab_element = name_strip(tab)
    $(".tabs-link.#{tab_element}.channel").length > 0

  is_there_such_private_tab = (tab) ->
    tab_element = name_strip(tab)
    $(".tabs-link.#{tab_element}.private").length > 0
    
  set_tab_unread = (tab, type) ->
    tab_element = name_strip(tab)
    tab = $(".tabs-content.#{tab_element}.#{type}")
    unless tab.hasClass('visible')
      # force tab link text color change on unread
      $(".tabs-link.#{tab_element}.#{type}").css('color', '#C20303')
  
  add_tab_members_handler = (channel, user) ->
    
    bare_channel = name_strip(channel)
    
    channel_members_items = $(".tabs-content.#{bare_channel}.channel").find('.members')
    channel_members_items.click (event) ->
      member = event.target.text
      return unless member?
      unless is_there_such_private_tab(member)
        create_private_tab(member, user)
        update_tab_list()
      show_tab(member, 'private')
    
  handle_private_message = (to) ->
    SS.events.on "newPrivateMessage", (message) ->
      
      bare_from = name_strip(message.from)
      
      unless is_there_such_private_tab(message.from)
        # create a tab for the user that sent us the priavte message if one doesn't already exist
        # explictly send the receives username, this might later passed to IRC and we need it be exact (not bare)
        create_private_tab(message.from, to)
        update_tab_list()
        
      message_view = $("<p>#{message.text}</p>")
      chatlog = $(".tabs-content.#{bare_from}.private").find('.chatlog')
      message_view.appendTo(chatlog)
      chatlog[0].scrollTop = chatlog[0].scrollHeight        # scroll down
      
      set_tab_unread(message.from, 'private')

  $('.join button').show().click ->
    
    channel = $('#joinedChannel').val()
    bare_channel = channel.replace('#', '')
    
    if is_there_such_channel_tab(bare_channel)
      $('#status').removeClass().addClass('error').text("Already joined ##{bare_channel}")
      return
    
    return $('#status').removeClass().addClass('error').text('Oops! You must type a channel first') unless channel.length > 0
    
    user = $('#user').text()
    
    SS.server.app.joinChannel bare_channel, (success) ->
      
      $('#joinedChannel').val('')
      unless success
        $('#status').removeClass().addClass('error').text("Failed joining channel ##{bare_channel}, please hold and try again soon.")
        return
      
      $('#status').removeClass().addClass('success').text("Joined channel ##{bare_channel}")
      
      # This is a channel name and will be passed latter to IRC so explicitly add # to the bare channel
      create_channel_tab("##{bare_channel}", user)
      
      update_tab_list()
      
      subscribe_to_channel_events(bare_channel, user)
            
      show_tab(bare_channel, 'channel')

    
  $('#reconnectButton').click (event) ->
    SS.socket.socket.reconnect()

  $('#disconnectButton').click (event) ->
    SS.socket.socket.disconnect()

  $('#currentUser').keypress (event) ->
    return unless event.keyCode == 13 or event.keyCode ==9
    current_user = $('#currentUser').val()
    return unless current_user.length > 0
    
    $('#user').text(current_user)
    SS.server.app.init current_user, (response) ->
        $('#response').removeClass().addClass(if response.error? then 'error' else 'success').text(response.message)
        $("#joinedChannel").focus()
        handle_private_message(current_user)
        
  $("#currentUser").focus()
