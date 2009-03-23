Ap4r
* by Kiwamu Kato, Shun'ichi Shinohara
* http://ap4r.rubyforge.org/wiki/wiki.pl?HomePage
* ap4r-user@rubyforge.org

== DESCRIPTION:
  
AP4R, Asynchronous Processing for Ruby, is the implementation of reliable asynchronous message processing. It provides message queuing, and message dispatching.
Using asynchronous processing, we can cut down turn-around-time of web applications by queuing, or can utilize more machine power by load-balancing.
Also AP4R nicely ties with your Ruby on Rails applications. See Hello World sample application from rubyforge.

For more information, please step in AP4R homepage!


== FEATURES / PROBLEMS TO SOLVE:
  
* Business logics can be implemented as simple Web applications, or ruby code, whether it's called asynchronously or synchronously.
* Asynchronous messaging is reliable by RDBMS persistence (now MySQL only) or file persistence, under the favor of reliable-msg.
* Load balancing over multiple AP4R processes on single/multiple servers is supported.
* Asynchronous logics are called via various protocols, such as XML-RPC, SOAP, HTTP POST, and more.
* Using store and forward function, at-least-once QoS level is provided.

== TYPICAL PROCESS FLOW:

1. A client (e.g. a web browser) makes a request to a web server (Apache, Lighttpd, etc...).
1. A rails application (a synchronous logic) is executed on mongrel via mod_proxy or something.
1. At the last of the synchronous logic, message(s) are put to AP4R (AP4R provides a helper).
1. Once the synchronous logic is done, the clients receives a response immediately.
1. AP4R queues the message, and requests it to the web server asynchronously.
1. An asynchronous logic, implemented as usual rails action, is executed. 


== SYNOPSIS:

* FIX (code sample of usage)

== REQUIREMENTS:

* FIX (list of requirements)

== INSTALL:

Use RubyGems command.

  $ sudo gem install ap4r --include-dependencies

	
== REFERENCES:

* Ruby Homepage
  * http://www.ruby-lang.org/ 
* Ruby on Rails tutorial
  * http://www.onlamp.com/pub/a/onlamp/2005/01/20/rails.html 
* MySQL tutorial
  * http://dev.mysql.com/doc/refman/5.0/en/index.html 
* reliable-msg
  * http://trac.labnotes.org/cgi-bin/trac.cgi/wiki/Ruby/ReliableMessaging 


== LICENSE:

* This software is licensed under the MIT license.
* Copyright(c) 2007 Future Architect Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
