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
    channel_ui = $(".#{channel}")
    
    SS.events.on "#{channel}:newMessage", (message) ->
      message_view = $("<p><strong>#{message.user}:</strong> #{message.text}</p>")
      chatlog = channel_ui.find('.chatlog')
      message_view.appendTo(chatlog)
      # dont annoy user while he is obviously reading by suddenly moving the scroll bar to the bototm
      unless Math.abs(chatlog[0].scrollHeight - chatlog[0].scrollTop) > 350 
        # none moved the scroll bar to a custom location up away (i.e further than 350), so scroll down
        chatlog[0].scrollTop = chatlog[0].scrollHeight
      
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

  
  show_channel = (channel) ->
    $(".visible").css('display', 'none')
    bare_channel = channel.replace(/@|#/, '')          
    invisble_chatbox = $(".#{bare_channel}")
    invisble_chatbox.css('display', 'block')
    invisble_chatbox.addClass('visible')
    invisble_chatbox.find('.message').focus()
  
  update_tab_list = ->
    # bind a handler for clicking on a the channel in the channels names tabs-list
    $('.tabs a').unbind('click')    
    $('.tabs a').click (event) ->
      
      # deal with the small closing x on the right side of the channel name
      event_text = event.target.text
      unless event_text?
        return
  
      channel = event_text.split(' ')[0]
      bare_channel = channel.replace(/@|#/, '')
      # remove the unread styling on the tab link (if it exsits)
      $(event.target).css('color', '#999')
      # make the chatbox visible after user clicked on the channel name in the channels names tab-list
      show_channel(bare_channel)

    $('.tabs-close').unbind('click')
    $('.tabs-close').click (event) ->

      # stop event from getting to the above '.tabs a' click handler.
      # this sperates clicking 'x' to close tab from switching tabs
      event.stopPropagation()
      
      tabs_link = $(event.target).parent('.tabs-link')
      channel = tabs_link.text().split(' ')[0]
      bare_channel = channel.replace(/@|#/, '')

      SS.server.app.leaveChannel channel, (success) ->
        return unless success

        SS.events.remove "#{bare_channel}:newMessage"
        SS.events.remove "#{bare_channel}:newMember"
        SS.events.remove "#{bare_channel}:leavingMember"
        SS.events.remove "#{bare_channel}:changingMember"        
        SS.events.remove "#{bare_channel}:currentMembers"
        SS.events.remove "#{bare_channel}:currentTopic"

        prev_tab = tabs_link.prev()
        tabs_link.remove()
        $(event.target).remove()
        $(".#{bare_channel}").remove()
        
        $('#status').removeClass().addClass('success').text("Left channel ##{bare_channel}")
        
        new_channel = prev_tab.text().split(' ')[0]
        new_bare_channel = new_channel.replace(/@|#/, '')
        show_channel(new_bare_channel)
  
  add_tab_chatbox_handler = (channel, user) ->
    
    bare_channel = channel.replace(/@|#/, '')
    destination = channel.replace('@', '') # replace '@' for sending to ops users, don't touch '#' for channels
    
    form = $(".#{bare_channel}")
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
    
  
  create_channel_tab = (channel, user) ->
    tab_nav = $('#tabs-nav').tmpl(channel: channel)
    $('.tabs').append(tab_nav)
    tab_content = $('#tabs-content').tmpl()
    $('#tabs').append(tab_content)
    
    # add a #{channel} class to identify the new tab with the channel name
    bare_channel = channel.replace(/@|#/, '')
    $('.tabs-content').last().addClass("#{bare_channel}")
    
    add_tab_chatbox_handler channel, user
    add_tab_members_handler channel, user
  
  is_there_such_channel_tab = (tab) ->
    
    $(".tabs-link:contains('#{tab}')").length > 0
    
  set_tab_unread = (tab) ->
    unread = $(".tabs-link:contains('#{tab}')")
    unless unread? and $(".#{tab}").hasClass('visible')
      # force tab link text color change on unread
      unread.css('color', '#C20303')
  
  add_tab_members_handler = (channel, user) ->
    
    bare_channel = channel.replace(/@|#/, '')
    
    channel_members_items = $(".#{bare_channel}").find('.members')
    channel_members_items.click (event) ->
      member = event.target.text
      return unless member?
      unless is_there_such_channel_tab(member)
        create_channel_tab(member, user)
        update_tab_list()
      show_channel(member)
    
  handle_private_message = (to) ->
    SS.events.on "newPrivateMessage", (message) ->
      
      bare_from = message.from.replace(/@|#/, '')
      
      unless is_there_such_channel_tab(bare_from)
        # create a tab for the user that sent us the priavte message if one doesn't already exist
        # explictly send the receives username, this might later passed to IRC and we need it be exact (not bare)
        create_channel_tab(message.from, to)
        update_tab_list()
        
      message_view = $("<p>#{message.text}</p>")
      chatlog = $(".#{bare_from}").find('.chatlog')
      message_view.appendTo(chatlog)
      
      set_tab_unread(bare_from)

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
            
      show_channel(bare_channel)

    
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
