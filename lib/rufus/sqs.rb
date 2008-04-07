#
#--
# Copyright (c) 2007-2008, John Mettraux, jmettraux@gmail.com
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#++
#

#
# Made in Japan
#
# John dot Mettraux at OpenWFE dot org
#

require 'base64'
require 'cgi'
require 'net/https'
require 'rexml/document'
require 'time'
require 'pp'

require 'rubygems'
require 'rufus/verbs'


module Rufus
module SQS

    #
    # An SQS message (after its creation).
    #
    class Message

        attr_reader :queue, :message_id, :message_body

        def initialize (queue, xml_element)

            @queue = queue
            @message_id = SQS::get_element_text(xml_element, "MessageId")
            @message_body = SQS::get_element_text(xml_element, "MessageBody")
        end

        #
        # Connects to the queue service and deletes this message in its queue.
        #
        def delete

            @queue.queue_service.delete_message(@queue, @message_id)
        end
    end

    #
    # An SQS queue (gathering all the necessary info about it 
    # in a single class).
    #
    class Queue

        attr_reader :queue_service, :host, :path, :name

        def initialize (queue_service, xml_element)

            @queue_service = queue_service

            s = xml_element.text.to_s
            m = Regexp.compile('^http://(.*)(/.*)(/.*$)').match(s)
            @host = m[1]
            @name = m[3][1..-1]
            @path = m[2] + m[3]
        end
    end

    #
    # As the name implies.
    #
    class QueueService

        AWS_VERSION = "2006-04-01"
        DEFAULT_QUEUE_HOST = "queue.amazonaws.com"

        def initialize (queue_host=nil)

            @queue_host = queue_host || DEFAULT_QUEUE_HOST
        end

        #
        # Lists the queues for the active AWS account.
        # If 'prefix' is given, only queues whose name begin with that
        # prefix will be returned.
        #
        def list_queues (prefix=nil)

            queues = []

            path = "/"
            path = "#{path}?QueueNamePrefix=#{prefix}" if prefix

            doc = do_action :get, @queue_host, path

            doc.elements.each("//QueueUrl") do |e|
                queues << Queue.new(self, e)
            end

            return queues
        end

        #
        # Creates a queue.
        #
        # If the queue name doesn't comply with SQS requirements for it,
        # an error will be raised.
        #
        def create_queue (queue_name)

            doc = do_action :post, @queue_host, "/?QueueName=#{queue_name}"

            doc.elements.each("//QueueUrl") do |e|
                return e.text.to_s
            end
        end

        #
        # Given some content ('text/plain' content), send it as a message to
        # a queue.
        # Returns the SQS message id (a String).
        #
        # The queue might be a queue name (String) or a Queue instance.
        #
        def put_message (queue, content)

            queue = resolve_queue(queue)

            doc = do_action :put, queue.host, "#{queue.path}/back", content

            #puts doc.to_s

            #status_code = SQS::get_element_text(doc, '//StatusCode')
            #message_id = SQS::get_element_text(doc, '//MessageId')
            #request_id = SQS::get_element_text(doc, '//RequestId')
            #{ :status_code => status_code, 
            #  :message_id => message_id, 
            #  :request_id => request_id }

            SQS::get_element_text(doc, '//MessageId')
        end

        alias :send_message :put_message

        #
        # Retrieves a bunch of messages from a queue. Returns a list of
        # Message instances.
        #
        # There are actually two optional params that this method understands :
        #
        # - :timeout  the duration in seconds of the message visibility in the
        #             queue
        # - :count    the max number of message to be returned by this call
        #
        # The queue might be a queue name (String) or a Queue instance.
        #
        def get_messages (queue, params={})

            queue = resolve_queue(queue)

            path = "#{queue.path}/front"

            path += "?" if params.size > 0

            timeout = params[:timeout]
            count = params[:count]

            path += "VisibilityTimeout=#{timeout}" if timeout
            path += "&" if timeout and count
            path += "NumberOfMessages=#{count}" if count

            doc = do_action :get, queue.host, path

            messages = []

            doc.elements.each("//Message") do |me|
                messages << Message.new(queue, me)
            end

            messages
        end

        #
        # Retrieves a single message from a queue. Returns an instance of
        # Message.
        #
        # The queue might be a queue name (String) or a Queue instance.
        #
        def get_message (queue, message_id)

            queue = resolve_queue(queue)

            path = "#{queue.path}/#{message_id}"

            begin
                doc = do_action :get, queue.host, path
                Message.new(queue, doc.root.elements[1])
            rescue Exception => e
                #puts e.message
                return nil if e.message.match "^404 .*$"
                raise e
            end
        end

        #
        # Deletes a given message.
        #
        # The queue might be a queue name (String) or a Queue instance.
        #
        def delete_message (queue, message_id)

            queue = resolve_queue(queue)

            path = "#{queue.path}/#{message_id}"
            #path = "#{queue.path}/#{CGI::escape(message_id)}"

            doc = do_action :delete, queue.host, path

            SQS::get_element_text(doc, "//StatusCode") == "Success"
        end

        #
        # Use with care !
        #
        # Attempts at deleting all the messages in a queue.
        # Returns the total count of messages deleted.
        #
        # A call on this method might take a certain time, as it has
        # to delete each message individually. AWS will perhaps
        # add a proper 'flush_queue' method later.
        #
        # The queue might be a queue name (String) or a Queue instance.
        #
        def flush_queue (queue)

            count = 0

            loop do

                l = get_messages queue, :timeout => 0, :count => 255

                break if l.length < 1

                l.each do |m|
                    m.delete
                    count += 1
                end
            end

            count
        end

        #
        # Deletes the queue. Returns true if the delete was successful.
        # You can empty a queue by called the method #flush_queue
        #
        # If 'force' is set to true, a flush will be performed on the
        # queue before the actual delete operation. It should ensure
        # a successful removal of the queue.
        #
        def delete_queue (queue, force=false)

            queue = resolve_queue(queue)

            flush_queue(queue) if force
            
            begin

                doc = do_action :delete, @queue_host, queue.path

            rescue Exception => e

                return false if e.message.match "^400 .*$"
            end

            SQS::get_element_text(doc, "//StatusCode") == "Success"
        end

        #
        # Given a queue name, a Queue instance is returned.
        #
        def get_queue (queue_name)

            l = list_queues(queue_name)

            l.each do |q|
                return q if q.name == queue_name
            end

            #return nil
            raise "found no queue named '#{queue_name}'"
        end

        protected

            #
            # 'queue' might be a Queue instance or a queue name. 
            # If it's a Queue instance, it is immediately returned,
            # else the Queue instance is looked up and returned.
            #
            def resolve_queue (queue)

                return queue if queue.kind_of?(Queue)
                get_queue queue.to_s
            end

            def do_action (action, host, path, content=nil)

                date = Time.now.httpdate

                h = {}

                h['AWS-Version'] = AWS_VERSION
                h['Date'] = date
                h['Content-type'] = 'text/plain'

                h['Content-length'] = content.length.to_s if content

                h['Authorization'] = generate_auth_header(
                    action, path, date, "text/plain")

                res = Rufus::Verbs::EndPoint.request(
                    action, 
                    :host => host,
                    :path => path, 
                    :d => content,
                    :headers => h)

                #case res
                #when Net::HTTPSuccess, Net::HTTPRedirection
                #    doc = REXML::Document.new(res.read_body)
                #else
                #    doc = res.error!
                #end
                doc = if res.is_a?(Net::HTTPSuccess)
                    REXML::Document.new(res.read_body)
                else
                    res.error!
                end

                raise_errors doc

                doc
            end

            #
            # Scans the SQS XML reply for potential errors and raises an
            # error if he encounters one.
            #
            def raise_errors (doc)

                doc.elements.each("//Error") do |e|

                    code = get_element_text(e, "Code")
                    return unless code

                    message = get_element_text(e, "Message")
                    raise "Rufus::SQS::#{code} : #{m.text.to_s}"
                end
            end

            #
            # Generates the 'AWS x:y" authorization header value.
            #
            def generate_auth_header (action, path, date, content_type)

                s = ""
                s << action.to_s.upcase
                s << "\n"

                #s << Base64.encode64(Digest::MD5.digest(content)).strip \
                #    if content
                    #
                    # documented but not necessary (not working)
                s << "\n"

                s << content_type
                s << "\n"

                s << date
                s << "\n"

                i = path.index '?'
                path = path[0..i-1] if i
                s << path

                #puts ">>>#{s}<<<"

                digest = OpenSSL::Digest::Digest.new 'sha1'

                key = ENV['AMAZON_SECRET_ACCESS_KEY']

                raise "No $AMAZON_SECRET_ACCESS_KEY env variable found" \
                    unless key

                sig = OpenSSL::HMAC.digest(digest, key, s)
                sig = Base64.encode64(sig).strip

                "AWS #{ENV['AMAZON_ACCESS_KEY_ID']}:#{sig}"
            end

    end

    #
    # A convenience method for returning the text of a sub element,
    # maybe there is something better in REXML, but I haven't found out
    # yet.
    #
    def SQS.get_element_text (parent_elt, elt_name)

        e = parent_elt.elements[elt_name]
        return nil unless e
        e.text.to_s
    end
end


#
# running directly...

if $0 == __FILE__

    if ENV['AMAZON_ACCESS_KEY_ID'] == nil or 
        ENV['AMAZON_SECRET_ACCESS_KEY'] == nil

        puts
        puts "env variables $AMAZON_ACCESS_KEY_ID and $AMAZON_SECRET_ACCESS_KEY are not set"
        puts
        exit 1
    end

    ACTIONS = {
        :list_queues => :list_queues,
        :lq => :list_queues,
        :create_queue => :create_queue,
        :cq => :create_queue,
        :delete_queue => :delete_queue,
        :dq => :delete_queue,
        :flush_queue => :flush_queue,
        :fq => :flush_queue,
        :get_message => :get_message,
        :gm => :get_message,
        :delete_message => :delete_message,
        :dm => :delete_message,
        :puts_message => :put_message,
        :pm => :put_message
    }

    b64 = false
    queue_host = nil

    require 'optparse'

    opts = OptionParser.new

    opts.banner = "Usage: sqs.rb [options] {action} [queue_name] [message_id]"
    opts.separator("")
    opts.separator("   known actions are :")
    opts.separator("")

    keys = ACTIONS.keys.collect { |k| k.to_s }.sort
    keys.each { |k| opts.separator("      - '#{k}'  (#{ACTIONS[k.intern]})") }

    opts.separator("")
    opts.separator("   options are :")
    opts.separator("")

    opts.on("-H", "--host", "AWS queue host") do |host|
        queue_host = host
    end

    opts.on("-h", "--help", "displays this help / usage") do
        STDERR.puts "\n#{opts.to_s}\n"
        exit 0
    end

    opts.on("-b", "--base64", "encode/decode messages with base64") do
        b64 = true
    end

    argv = opts.parse(ARGV)

    if argv.length < 1
        STDERR.puts "\n#{opts.to_s}\n"
        exit 0
    end

    a = argv[0]
    queue_name = argv[1]
    message_id = argv[2]

    action = ACTIONS[a.intern]

    unless action
        STDERR.puts "unknown action '#{a}'"
        exit 1
    end

    qs = SQS::QueueService.new

    STDERR.puts "#{action.to_s}..."

    #
    # just do it

    case action
    when :list_queues, :create_queue, :delete_queue, :flush_queue

        pp qs.send(action, queue_name)

    when :get_message

        if message_id
            m = qs.get_message(queue_name, message_id)
            body = m.message_body
            body = Base64.decode64(body) if b64
            puts body
        else
            pp qs.get_messages(queue_name, :timeout => 0, :count => 255)
        end

    when :delete_message

        raise "argument 'message_id' is missing" unless message_id
        pp qs.delete_message(queue_name, message_id)

    when :put_message

        message = argv[2]

        unless message
            message = ""
            while true
                s = STDIN.gets()
                break if s == nil
                message += s[0..-2]
            end
        end

        message = Base64.encode64(message).strip if b64

        pp qs.put_message(queue_name, message)
    else

        STDERR.puts "not yet implemented..."
    end

end
end

