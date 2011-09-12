# constant-stream - SocketStream as a solution to the traveling IRC-man problem

## Introduction

constant-stream is a web app written for the IRC chatter on-the-go.
It allows him to connect to a IRC server through the service web interface, but since constant-stream is acting as a client on his behalf, it is possible for the chatter to put his laptop into sleep mode, take a walk but have all of the private messages that were sent to him and all of the exchanged messages in his favorite channels during the time he was offline. When he'll get online again, the stored messages will appear in his browser. It's like reading the channel logs, only just a tad bit simpler.

Putting these minor benefits aside, constant-stream goal is to be a small demo application for the [SocketStream](https://github.com/socketstream/socketstream/) framework.

## Example Instance

An example instance of the application allowing you to connect to the [freenode](http://freenode.net) IRC network is up and running on [Joyent no.de](http://no.de) platform, feel free to check it [out](http://constant-stream.no.de/). If for some reason you do decide to use it for your IRC needs, do expect stability and performance issues (but please report them to the issues tracker).

## Installation

    % git clone git@github.com:syrio/constant-stream.git
    % cd constant-stream
    % npm install

### Define the IRC server

Add the name of the IRC server you want to connect to by editing config/app.coffee directly or add environment-based configuration to config/environments

    irc:
      server: 'irc.server.net'
      
You can use the excellent [ircd.js](https://github.com/alexyoung/ircd.js/) Node.js IRC server for experimenting on your own.

### Configure the client timeout

By default, the constant-stream server will check every 999 seconds to see which traveling client hasn't sent a heartbeat for 24 hours, it then disconnects all IRC connections and delete all of the stored messages of any client that has timed out. You can configure the default constants (_timeout_ is in minutes, _interval_ is in seconds) by editing the app configuration (config/app.coffee) -

    offline_expire:
      timeout: 24*60
      interval: 999

### Deployment

    % $YOUR_REDIS_PATH/src/redis-server
    % cd constant-stream
    % npm start

And then visit http://localhost:3000

## Internals

## Server-side

The application server side manages the client's connection against the IRC server, and is utilizing Redis to store the messages until the client connects back to the application server.

When a client first connects, 

In order to be notified on which client is offline as soon as the client disconnects, the server uses SocketStream events object, SS.events (see config/events.coffee and SocketStream documentation for SocketStream own examples) and registers handlers for the following events - 

  * client:disconnect
  * client:connect
  * channel:subscribe
  * channel:unsubscribe

It uses these events to keep an updated representation of the state of it's clients and to react accordingly. When a client disconnects, it's session id is saved into a set of offline sessions stored with Redis. When a client reconnects, the server detects whether this is a new client or perhaps a traveling client that is reconnecting by comparing the session id of a session that generated a client:connect event with the list of offline sessions.

Messages are being sent using SocketStream users Pub/Sub, even though there is no authentication involved with constant-stream. This is done by assigning (using the @session.setUserId function) each unique session (that is, a user using it's browser to connect to constant-stream) as the user id that match with that session, essentially mimicking a user login for this session. SocketStream users Pub/Sub allows the server to send messages to specific users and this comes handy when you have multiple constant-stream users that are connected to the same channels as the other and with private messaging.

Since we are now using SocketStream users feature, even though the server doesn't uses the built-in users-online mechanism to calculate who is online and who isn't offline, it does uses it to conclude which users have been traveling for too long and have timeout their connection (see the timeout configuration and the client side sections for more general details).

### External libs

Redis was mentioned briefly since pretty much baked-in into SocketStream. It is worth mentioning only because constant-stream wraps it by using a small helper class (see StreamStorage in the helpers module) around it to provide a simple and decoupled storage interface that is easily testable.

As far as IRC connectivity, the application server currently uses the [node-irc](https://github.com/martynsmith/node-irc) IRC client library wrapped by a small helper class (see helpers.StreamIrc in the helpers module). It is a very easy-to-use library, but the primary reason it is being used is to reduce the amount of new code in the example. Please note that some tests have shown that this lib might introduce some fatal errors that are hard to wrap within the application code, but a relevant pull request to the irc lib is already underway. 

### Server files

The server-side code is stored in the app/server/app.coffee and node\_modules/helpers.coffee files.


## Client-side

#### Introduction

The client side is, as expected, a single-page-app, based on jQuery. It mimics a very basic IRC client, allowing you to choose a username, join/leave chat channels on the server and chat with other IRC participants (members) using private messages. It displays the status of the connection to the server and any errors that might have happened.

### Events

The client uses SocketStream Pub/Sub capability by listening for the following events - 

  * New message
  * New private message
  * New joining member
  * Leaving member
  * Current channel topic
  * Current channel members.

The client listens to events using the IRC channel as the SocketStream Pub/Sub channel name, but uses name spacing in the event name to bind each event to a specific events. Currently, when a client adds an event handler for an event named 'myEvent', then the provided handler will be executed even if an event of the same name was fired by an all together different Pub/Sub channel. This can be seen clearly in app/client/app.coffee (corresponds to the list of events above) -

``` coffee-script

    SS.events.on "#{channel}:newMessage", (message) -> ...
    
    SS.events.on "#{channel}:newMember", (member) -> ...
    
    SS.events.on "#{channel}:leavingMember", (member) -> ...
    
    SS.events.on "#{channel}:currentTopic", (topic) -> ...
    
    SS.events.on "#{channel}:currentMembers", (members) -> ...

    ...
    
    SS.events.on "newPrivateMessage", (message) -> ...

```

### Realoding the app

Upon reloading the app by refreshing the page or closing and reopening the browser causes complete loss of state in the client since no HTML5 storage is being used in this example. The server will recognize this reload and will assume the client wanted to create a new session, killing all of the reloaded session live IRC connection and deleting all (if any) of the stored messages for that client.

### Browser compatibility

Tested to work with Google Chrome 13.0.780.220. Basic sanity tests were done with Firefox 7.0 and Safari Version 5.0.2 (6533.18.5).

### Client files

The client-side code is stored in the app/client/app.coffee file.


## Tests

### Current state

The majority of the server-side code (the helpers classes, located at node_modules/helpers.coffee) have full passing Jasmine/sinon unit-tests that also can be used as documentation. 

### sinon-jasmine modification

Do note that the test folder contains a modified version of the [sinon-jasmine.js matchers extension](https://github.com/froots/jasmine-sinon) that works on node and is wrapped inside a function to prevent polluting the global scope.

### Application code

Both the client and server application code doesn't have any tests at the moment (which will mostly be integration and end-to-end tests).


### Running the tests

    % npm test


### License

Released under the MIT license.